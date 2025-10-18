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
    # Get Agent and Customer roles
    agent_roles = Role.with_permissions('ticket.agent')
    customer_roles = Role.with_permissions('ticket.customer')
    
    role_ids = []
    role_ids += agent_roles.pluck(:id) if agent_roles.present?
    role_ids += customer_roles.pluck(:id) if customer_roles.present?
    role_ids.uniq!
    
    # Get all active users with Agent or Customer roles
    users = User
      .joins(:roles)
      .where(roles: { id: role_ids })
      .where(active: true)
      .distinct
      .limit(1000)
    
    # Exclude current user
    users = users.where.not(id: current_user.id) if current_user
    
    # Format response
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

