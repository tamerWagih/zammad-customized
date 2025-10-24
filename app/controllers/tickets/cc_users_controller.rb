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
    search_query = params[:search]&.strip
    
    # Allow up to 1000 users for dropdown (reasonable limit)
    per_page = [params[:per_page]&.to_i || 200, 1000].min
    page = params[:page]&.to_i || 1
    offset = (page - 1) * per_page

    # Get ALL users with agent OR customer PERMISSIONS
    # CRITICAL: Use a more reliable query that doesn't miss users
    # 
    # Strategy: Get ALL active users, then filter by permissions in Ruby
    # This ensures we don't miss any users due to complex JOIN issues
    
    # First, get all active users except current user
    base_users = User.where(active: true)
                     .where.not(id: current_user.id)
    
    Rails.logger.info "[CC_API] Total active users (excluding current): #{base_users.count}"
    
    # Filter to only agents and customers using Ruby (more reliable than SQL joins)
    all_users = base_users.select do |user|
      user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
    end
    
    Rails.logger.info "[CC_API] Found #{all_users.count} users with agent/customer permissions"
    Rails.logger.info "[CC_API] EXCLUDING current user: #{current_user.id} (#{current_user.login})"
    
    # Debug: Log all user IDs
    all_user_ids = all_users.map(&:id)
    Rails.logger.info "[CC_API] All user IDs: #{all_user_ids.inspect}"
    Rails.logger.info "[CC_API] Current user #{current_user.id} in list? #{all_user_ids.include?(current_user.id)}"

    # Search (in Ruby since we already loaded users)
    if search_query.present?
      search_pattern = search_query.downcase
      all_users = all_users.select do |user|
        user.firstname&.downcase&.include?(search_pattern) ||
        user.lastname&.downcase&.include?(search_pattern) ||
        user.login&.downcase&.include?(search_pattern) ||
        user.email&.downcase&.include?(search_pattern)
      end
      Rails.logger.info "[CC_API] After search filter: #{all_users.count} users"
    end

    # Sort users
    all_users = all_users.sort_by { |u| [u.firstname || '', u.lastname || '', u.login || ''] }
    
    # Paginate
    total_count = all_users.count
    users = all_users.slice(offset, per_page) || []

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
