# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketCcsController < ApplicationController
  prepend_before_action :authentication_check

  # GET /api/v1/tickets/cc_users
  #
  # Returns a list of users (agents and customers) that can be CC'd on tickets
  # Accessible by both agents and customers
  #
  # @response_message 200 [Array<User>] List of users available for CC
  # @response_message 403               Forbidden / Invalid session
  def index
    # Use the same User.search method that /users/search uses
    # This ensures we get the same results as the approval modal

    # Get Agent and Customer roles
    agent_roles = Role.with_permissions('ticket.agent')
    customer_roles = Role.with_permissions('ticket.customer')

    role_ids = []
    role_ids += agent_roles.pluck(:id) if agent_roles.present?
    role_ids += customer_roles.pluck(:id) if customer_roles.present?
    role_ids.uniq!

    # Use User.search with role_ids (same as approval modal)
    search_result = User.search(
      role_ids:     role_ids,
      limit:        1000,
      current_user: current_user,
      full:         true,
    ) || { objects: [] }

    users = search_result[:objects] || []

    # Exclude current user and inactive users
    users = users.select do |user|
      user.id != current_user&.id && user.active
    end

    # Format response (same format as before)
    users_list = users.map do |user|
      {
        id: user.id,
        login: user.login,
        firstname: user.firstname,
        lastname: user.lastname,
        email: user.email,
        active: user.active
      }
    end

    render json: users_list, status: :ok
  end
end
