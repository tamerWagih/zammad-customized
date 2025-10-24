# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Tickets::CcUsersController < ApplicationController
  prepend_before_action :authentication_check

  # GET /api/v1/tickets/cc_users
  # Returns agents and customers (excludes admins)
  def index
    Rails.logger.info "[CC_API] ===== CC USERS REQUEST ====="
    Rails.logger.info "[CC_API] Current user: #{current_user&.id} (#{current_user&.login})"
    
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

    # Get ALL users with agent OR customer PERMISSIONS (not role names!)
    # This catches users with these permissions through ANY role (Agent, Approver, Admin No-Agent, etc.)
    
    # Get permission IDs for ticket.agent and ticket.customer
    agent_permission = Permission.find_by(name: 'ticket.agent')
    customer_permission = Permission.find_by(name: 'ticket.customer')
    permission_ids = [agent_permission&.id, customer_permission&.id].compact
    
    Rails.logger.info "[CC_API] Permission IDs to check: #{permission_ids}"
    
    # Get users with these permissions through their roles
    query = User.joins(roles: :permissions)
                .where(permissions: { id: permission_ids })
                .where(active: true)
                .where.not(id: current_user.id)
                .distinct
    
    Rails.logger.info "[CC_API] Found #{query.count} users with agent/customer permissions"
    Rails.logger.info "[CC_API] EXCLUDING current user: #{current_user.id} (#{current_user.login})"
    
    # Debug: Log all user IDs before search
    all_user_ids = query.pluck(:id)
    Rails.logger.info "[CC_API] All user IDs (before search): #{all_user_ids.inspect}"
    Rails.logger.info "[CC_API] Current user #{current_user.id} in list? #{all_user_ids.include?(current_user.id)}"

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

    Rails.logger.info "[CC_API] Total matching users: #{total_count}"
    Rails.logger.info "[CC_API] Returning #{users.length} users (page #{page})"

    # Format response
    users_list = users.map do |user|
      is_agent = user.permissions?('ticket.agent')
      is_customer = user.permissions?('ticket.customer')
      
      Rails.logger.info "[CC_API] User #{user.id} (#{user.login}): agent=#{is_agent}, customer=#{is_customer}, roles=#{user.roles.pluck(:name)}"
      
      {
        id:        user.id,
        login:     user.login,
        firstname: user.firstname,
        lastname:  user.lastname,
        email:     user.email,
        active:    user.active,
        user_type: is_agent ? 'agent' : 'customer'
      }
    end

    Rails.logger.info "[CC_API] ===== RESPONSE SENT ====="
    
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
