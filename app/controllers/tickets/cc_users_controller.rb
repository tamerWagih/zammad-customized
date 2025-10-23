# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Tickets::CcUsersController < ApplicationController
  prepend_before_action :authentication_check

  # GET /api/v1/tickets/cc_users
  # Returns agents and customers (excludes admins)
  def index
    return render json: { error: 'Unauthorized' }, status: :forbidden unless current_user

    # Check permissions
    cc_permissions = ['ticket.agent', 'ticket.customer']
    has_access = current_user.permissions.any? { |p| cc_permissions.include?(p.name) }
    return render json: { error: 'Unauthorized' }, status: :forbidden unless has_access

    # Get pagination and search
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 50, 200].min
    search_query = params[:search]&.strip
    offset = (page - 1) * per_page

    # Get agent and customer roles
    agent_roles = Role.with_permissions('ticket.agent')
    customer_roles = Role.with_permissions('ticket.customer')
    target_role_ids = (agent_roles.pluck(:id) + customer_roles.pluck(:id)).uniq

    # Get admin roles to exclude
    admin_roles = Role.with_permissions(['admin', 'admin.user', 'admin.ticket'])
    admin_role_ids = admin_roles.pluck(:id)

    # Build query
    query = User.joins(:roles)
                .where(roles: { id: target_role_ids })
                .where(active: true)
                .where.not(id: current_user.id)
                .distinct

    # Exclude admins
    if admin_role_ids.any?
      admin_user_ids = User.joins(:roles)
                          .where(roles: { id: admin_role_ids })
                          .distinct
                          .pluck(:id)
      query = query.where.not(id: admin_user_ids) if admin_user_ids.any?
    end

    # Search
    if search_query.present?
      search_pattern = "%#{search_query.downcase}%"
      query = query.where(
        'LOWER(users.firstname) ILIKE ? OR LOWER(users.lastname) ILIKE ? OR LOWER(users.login) ILIKE ? OR LOWER(users.email) ILIKE ?',
        search_pattern, search_pattern, search_pattern, search_pattern
      )
    end

    # Order and paginate
    query = query.order(:firstname, :lastname, :login)
    total_count = query.count
    users = query.limit(per_page).offset(offset)

    # Format response
    users_list = users.map do |user|
      {
        id:        user.id,
        login:     user.login,
        firstname: user.firstname,
        lastname:  user.lastname,
        email:     user.email,
        active:    user.active,
        user_type: user.permissions?('ticket.agent') ? 'agent' : 'customer'
      }
    end

    total_pages = (total_count.to_f / per_page).ceil
    render json: {
      users: users_list,
      pagination: {
        current_page:  page,
        per_page:      per_page,
        total_count:   total_count,
        total_pages:   total_pages,
        has_next_page: page < total_pages
      }
    }
  end
end
