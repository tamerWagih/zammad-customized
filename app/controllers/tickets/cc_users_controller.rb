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

    # Get search query (check multiple param names for compatibility)
    search_query = (params[:query] || params[:search] || params[:term] || params[:q])&.strip
    
    # SIMPLE: No preloading. Only return results when user searches.
    # This is more efficient and prevents loading thousands of users.
    
    if search_query.blank?
      # No search query = return empty (user must type to search)
      render json: { users: [], total: 0 }
      return
    end
    
    # Require at least 2 characters to search
    if search_query.length < 2
      render json: { users: [], total: 0 }
      return
    end
    
    # Search in database (SQL ILIKE for performance)
    # CRITICAL: Exclude current user (ticket creator)
    search_pattern = "%#{search_query}%"
    
    Rails.logger.info "CC search: query='#{search_query}', current_user=#{current_user.id}"
    
    users = User.where(active: true)
                .where.not(id: current_user.id)
                .where(
                  'firstname ILIKE ? OR lastname ILIKE ? OR email ILIKE ? OR login ILIKE ?',
                  search_pattern, search_pattern, search_pattern, search_pattern
                )
                .order(:firstname, :lastname)
                .limit(100)  # Max 100 results
    
    Rails.logger.info "CC search: found #{users.count} users before permission filter"
    
    # Filter to only agents and customers
    users = users.select { |u| u.permissions?('ticket.agent') || u.permissions?('ticket.customer') }
    
    Rails.logger.info "CC search: #{users.count} users after permission filter"
    
    total_count = users.count

    # Format response
    users_list = users.map do |user|
      is_agent = user.permissions?('ticket.agent')
      is_customer = user.permissions?('ticket.customer')
      
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
  rescue => e
    Rails.logger.error "CC users API error: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render json: { error: e.message, users: [], total: 0 }, status: 500
  end
end
