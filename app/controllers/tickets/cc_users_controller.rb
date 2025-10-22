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
    Rails.logger.info "[CC_API] Request params: #{params.inspect}"

    # Get pagination and search parameters
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 50, 100].min # Max 100 per page
    search_query = params[:search]&.strip
    offset = (page - 1) * per_page

    Rails.logger.info "[CC_API] Pagination: page=#{page}, per_page=#{per_page}, offset=#{offset}"
    Rails.logger.info "[CC_API] Search query: #{search_query.inspect}"

    # Get Agent and Customer roles efficiently
    agent_roles = Role.with_permissions('ticket.agent')
    customer_roles = Role.with_permissions('ticket.customer')

    role_ids = []
    role_ids += agent_roles.pluck(:id) if agent_roles.present?
    role_ids += customer_roles.pluck(:id) if customer_roles.present?
    role_ids.uniq!

    Rails.logger.info "[CC_API] Target role IDs: #{role_ids.inspect}"

    # Build efficient query with proper SQL joins
    query = User.joins(:roles)
                .where(roles: { id: role_ids })
                .where(active: true)
                .where.not(id: current_user&.id)
                .distinct

    # Add search functionality if query provided
    if search_query.present?
      # Search in firstname, lastname, login, and email
      search_pattern = "%#{search_query.downcase}%"
      query = query.where(
        "LOWER(users.firstname) LIKE ? OR LOWER(users.lastname) LIKE ? OR LOWER(users.login) LIKE ? OR LOWER(users.email) LIKE ?",
        search_pattern, search_pattern, search_pattern, search_pattern
      )
      Rails.logger.info "[CC_API] Applied search filter: #{search_query}"
    end

    # Get total count for pagination metadata
    total_count = query.count
    Rails.logger.info "[CC_API] Total matching users: #{total_count}"

    # Apply pagination and ordering
    users = query.order(:firstname, :lastname, :login)
                 .limit(per_page)
                 .offset(offset)

    Rails.logger.info "[CC_API] Returning #{users.count} users (page #{page}/#{(total_count.to_f / per_page).ceil})"

    # Format response with pagination metadata
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

    # Build pagination metadata
    total_pages = (total_count.to_f / per_page).ceil
    pagination_meta = {
      current_page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_next_page: page < total_pages,
      has_prev_page: page > 1
    }

    Rails.logger.info "[CC_API] Pagination meta: #{pagination_meta.inspect}"

    # Return response with pagination metadata
    render json: {
      users: users_list,
      pagination: pagination_meta
    }, status: :ok
  end
end

