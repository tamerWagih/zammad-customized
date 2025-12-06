# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Tickets::CcUsersController < ApplicationController
  prepend_before_action :authentication_check

  # GET /api/v1/tickets/cc_users
  # Returns active users with Agent OR Customer permissions (excluding current user)
  def index
    return render json: { error: 'Unauthorized' }, status: :forbidden unless current_user

    # Check permissions
    cc_permissions = ['ticket.agent', 'ticket.customer']
    has_access = current_user.permissions.any? { |p| cc_permissions.include?(p.name) }
    return render json: { error: 'Unauthorized' }, status: :forbidden unless has_access

    # Get pagination and search
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 50, 200].min  # Max 200 users per request
    search_query = params[:search]&.strip
    offset = (page - 1) * per_page

    # Get Agent and Customer role IDs
    agent_role = Role.find_by(name: 'Agent')
    customer_role = Role.find_by(name: 'Customer')
    role_ids = [agent_role&.id, customer_role&.id].compact

    # SQL-based filtering (efficient, same as Approval search!)
    # Uses database joins and WHERE clauses, not Ruby loops
    all_users = User.joins(:roles)
                    .where(active: true)
                    .where.not(id: current_user.id)
                    .where(roles: { id: role_ids })
                    .distinct

    # SQL-based search (if query provided) - much faster than Ruby loops
    if search_query.present?
      search_pattern = "%#{search_query.downcase}%"
      all_users = all_users.where(
        "LOWER(users.firstname) LIKE ? OR LOWER(users.lastname) LIKE ? OR " \
        "LOWER(users.login) LIKE ? OR LOWER(users.email) LIKE ?",
        search_pattern, search_pattern, search_pattern, search_pattern
      )
    end

    # Get total count BEFORE pagination (for pagination info)
    total_count = all_users.count
    
    # SQL sorting and pagination (only loads needed records!)
    users = all_users.order(:firstname, :lastname, :login)
                     .offset(offset)
                     .limit(per_page)

    # Format response
    users_list = users.map do |user|
      # Use role_ids to determine type (consistent with filtering logic)
      has_agent_role = user.role_ids.include?(agent_role&.id)
      has_customer_role = user.role_ids.include?(customer_role&.id)
      
      # Determine primary user type (agent takes priority if user has both roles)
      user_type = if has_agent_role
                    'agent'
                  elsif has_customer_role
                    'customer'
                  else
                    'user'  # Shouldn't happen due to filtering, but safe fallback
                  end
      
      {
        id:        user.id,
        login:     user.login,
        firstname: user.firstname,
        lastname:  user.lastname,
        email:     user.email,
        active:    user.active,
        user_type: user_type
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
