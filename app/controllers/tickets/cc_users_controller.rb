# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Tickets::CcUsersController < ApplicationController
  prepend_before_action :authentication_check

  # GET /api/v1/tickets/cc_users
  #
  # Returns a list of users (agents and customers) that can be CC'd on tickets
  # Accessible by both agents and customers
  #
  # @response_message 200 [Array<User>] List of users available for CC
  # @response_message 403               Forbidden / Invalid session
  def index
    Rails.logger.info "[CC_API] CC users endpoint called by user #{current_user.id}"

    # Get Agent and Customer roles
    agent_roles = Role.with_permissions('ticket.agent')
    customer_roles = Role.with_permissions('ticket.customer')

    Rails.logger.info "[CC_API] Agent roles found: #{agent_roles.count}"
    Rails.logger.info "[CC_API] Customer roles found: #{customer_roles.count}"

    role_ids = []
    role_ids += agent_roles.pluck(:id) if agent_roles.present?
    role_ids += customer_roles.pluck(:id) if customer_roles.present?
    role_ids.uniq!

    Rails.logger.info "[CC_API] Role IDs: #{role_ids.inspect}"
    Rails.logger.info "[CC_API] Current user: #{current_user.id} (#{current_user.permissions})"

    # Use User.search with role_ids (same as approval modal)
    search_result = User.search(
      role_ids:     role_ids,
      limit:        1000,
      current_user: current_user,
      full:         true,
    ) || { objects: [] }

    Rails.logger.info "[CC_API] Search result count: #{search_result[:objects]&.count || 0}"
    Rails.logger.info "[CC_API] Search result: #{search_result.inspect}"
    
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

