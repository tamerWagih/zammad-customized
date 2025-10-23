# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Tickets::CcUsersController < ApplicationController
  prepend_before_action :authentication_check

  # GET /api/v1/tickets/cc_users
  #
  # Returns a list of agents and customers that can be CC'd on tickets
  # Goal: Allow sharing ticket access with other agents and customers
  # Includes: ONLY agents and customers (excludes admins and other roles)
  # Excludes: The current user (ticket creator) and users with admin permissions
  # Accessible by users with agent or customer permissions
  # Note: CC grants ticket access regardless of group permissions
  #
  # @response_message 200 [Array<User>] List of agents and customers available for CC
  # @response_message 403               Forbidden / Invalid session
  def index
    # Enhanced permission check - ensure user has ticket access permissions
    return render json: { error: 'Unauthorized - No ticket access permissions' }, status: :forbidden unless current_user

    # Check if current user has agent or customer permissions (required to CC users)
    # This ensures users can only CC other users if they themselves have ticket access
    cc_permissions = ['ticket.agent', 'ticket.customer']
    has_cc_access = current_user.permissions.any? { |p| cc_permissions.include?(p.name) }

    return render json: {
      error: 'Unauthorized - You need agent or customer permissions to CC users',
      required_permissions: cc_permissions,
      user_permissions: current_user.permissions.pluck(:name)
    }, status: :forbidden unless has_cc_access

    Rails.logger.info "[CC_API] CC users endpoint called by user #{current_user.id}"
    Rails.logger.info "[CC_API] Current user: #{current_user.login} (#{current_user.email})"
    Rails.logger.info "[CC_API] Current user roles: #{current_user.roles.pluck(:name)}"
    Rails.logger.info "[CC_API] Current user permissions: #{current_user.permissions.pluck(:name)}"
    Rails.logger.info "[CC_API] Current user has CC access: #{has_cc_access}"
    Rails.logger.info "[CC_API] Request params: #{params.inspect}"

    # Get pagination and search parameters
    page = params[:page]&.to_i || 1
    # Increase default per_page for better UX, but cap for performance
    default_per_page = search_query.present? ? 100 : 50  # More results for search
    per_page = [params[:per_page]&.to_i || default_per_page, 200].min # Max 200 per page for large orgs
    search_query = params[:search]&.strip
    group_id = params[:group_id]&.to_i  # Get group_id for filtering
    offset = (page - 1) * per_page

    Rails.logger.info "[CC_API] Pagination: page=#{page}, per_page=#{per_page}, offset=#{offset}"
    Rails.logger.info "[CC_API] Search query: #{search_query.inspect}"
    Rails.logger.info "[CC_API] Performance mode: #{search_query.present? ? 'search' : 'browse'}"

    # Get ONLY Agent and Customer roles (not admins or other roles)
    # Goal: Allow sharing ticket access with other agents and customers
    # CRITICAL: Must explicitly exclude users with admin permissions
    agent_roles = Role.with_permissions('ticket.agent')
    customer_roles = Role.with_permissions('ticket.customer')

    # Get admin roles to explicitly exclude users who have admin permissions
    admin_permissions = ['admin', 'admin.user', 'admin.ticket', 'admin.group', 'admin.role']
    admin_roles = Role.with_permissions(admin_permissions)

    Rails.logger.info "[CC_API] All roles in system: #{Role.pluck(:name).inspect}"
    Rails.logger.info "[CC_API] All permissions in system: #{Permission.pluck(:name).inspect}"

    # Get role IDs for agents and customers
    agent_role_ids = agent_roles.pluck(:id) if agent_roles.present?
    customer_role_ids = customer_roles.pluck(:id) if customer_roles.present?
    target_role_ids = (agent_role_ids.to_a + customer_role_ids.to_a).uniq

    # Get admin role IDs to exclude users who have admin permissions
    admin_role_ids = admin_roles.pluck(:id) if admin_roles.present?
    admin_role_ids ||= []

    Rails.logger.info "[CC_API] Agent roles found: #{agent_roles.count}"
    Rails.logger.info "[CC_API] Customer roles found: #{customer_roles.count}"
    Rails.logger.info "[CC_API] Admin roles found: #{admin_roles.count}"
    Rails.logger.info "[CC_API] Target role IDs (agents+customers): #{target_role_ids.inspect}"
    Rails.logger.info "[CC_API] Admin role IDs to exclude: #{admin_role_ids.inspect}"

    # Build query: Users with agent/customer roles AND proper permission checks
    # Use a single join to roles for better performance
    query = User.joins(:roles)
                .where(roles: { id: target_role_ids })
                .where(active: true)
                .where.not(id: current_user&.id)
                .distinct

    # CRITICAL: Exclude users who have admin permissions (even if they have agent permissions)
    # Use a subquery to properly exclude admin users
    if admin_role_ids.any?
      admin_user_ids = User.joins(:roles)
                          .where(roles: { id: admin_role_ids })
                          .distinct
                          .pluck(:id)
      query = query.where.not(id: admin_user_ids) if admin_user_ids.any?
      Rails.logger.info "[CC_API] Excluded #{admin_user_ids.length} admin users"
    end

    # In Zammad, CC grants ticket access regardless of group permissions
    # Users can CC any agent/customer, and the CC relationship grants access to the ticket
    # No group filtering needed - CC access overrides group restrictions
    Rails.logger.info "[CC_API] CC grants ticket access - showing all eligible agents/customers"
    Rails.logger.info "[CC_API] Admin exclusion applied - CC access will be granted to selected users"

    Rails.logger.info "[CC_API] Query after admin exclusion: #{query.to_sql}"

    # Additional validation: Ensure current user would be included if not excluded
    current_user_would_be_included = User.joins(:roles)
                                        .where(roles: { id: target_role_ids })
                                        .where(active: true)
                                        .where(id: current_user&.id)
                                        .exists?

    # Check if current user has admin permissions (should be excluded from CC list)
    current_user_has_admin = admin_role_ids.any? && User.joins(:roles)
                                                       .where(roles: { id: admin_role_ids })
                                                       .where(id: current_user&.id)
                                                       .exists?

    Rails.logger.info "[CC_API] Current user would be included (if not excluded): #{current_user_would_be_included}"
    Rails.logger.info "[CC_API] Current user has admin permissions (excluded): #{current_user_has_admin}"
    Rails.logger.info "[CC_API] Current user permissions that grant access: #{current_user&.permissions&.where(name: cc_permissions)&.pluck(:name)}"

    # Debug: Check if we have any users with these roles (after admin exclusion)
    debug_query = User.joins(:roles)
                      .where(roles: { id: target_role_ids })
                      .where(active: true)
                      .distinct

    # Exclude admin users from debug query too
    if admin_role_ids.any?
      admin_user_ids = User.joins(:roles)
                          .where(roles: { id: admin_role_ids })
                          .distinct
                          .pluck(:id)
      debug_query = debug_query.where.not(id: admin_user_ids) if admin_user_ids.any?
    end

    Rails.logger.info "[CC_API] Total users with agent/customer roles (after admin exclusion): #{debug_query.count}"
    Rails.logger.info "[CC_API] Sample users with agent/customer roles: #{debug_query.limit(5).pluck(:id, :firstname, :lastname, :login).inspect}"

    # Additional debugging: Check role distribution
    role_user_counts = {}
    agent_roles.each do |role|
      count = User.joins(:roles).where(roles: { id: role.id }).where(active: true).distinct.count
      role_user_counts["Agent-#{role.name}"] = count
    end
    customer_roles.each do |role|
      count = User.joins(:roles).where(roles: { id: role.id }).where(active: true).distinct.count
      role_user_counts["Customer-#{role.name}"] = count
    end
    Rails.logger.info "[CC_API] Users by role (total system): #{role_user_counts.inspect}"

    # Add search functionality if query provided
    if search_query.present?
      # Optimize search: Use ILIKE for case-insensitive search and prioritize exact matches
      search_pattern = "%#{search_query.downcase}%"

      # Search in multiple fields with optimized query
      query = query.where(
        "LOWER(users.firstname) ILIKE ? OR LOWER(users.lastname) ILIKE ? OR LOWER(users.login) ILIKE ? OR LOWER(users.email) ILIKE ?",
        search_pattern, search_pattern, search_pattern, search_pattern
      )

      # For better performance with large datasets, order by relevance
      query = query.order(
        # Prioritize exact matches in login or email
        "CASE WHEN LOWER(users.login) = ? THEN 1 WHEN LOWER(users.email) = ? THEN 2 ELSE 3 END",
        search_query.downcase, search_query.downcase
      ).order(:firstname, :lastname)

      Rails.logger.info "[CC_API] Applied search filter: #{search_query}"
    else
      # Default ordering for browsing
      query = query.order(:firstname, :lastname, :login)
    end

    # Get total count for pagination metadata (with performance optimization)
    total_count = query.count
    Rails.logger.info "[CC_API] Total matching users: #{total_count}"

    # If no users found, log the current user's roles for debugging
    if total_count == 0
      Rails.logger.info "[CC_API] No agents or customers found! Current user roles: #{current_user&.roles&.pluck(:name)}"
      Rails.logger.info "[CC_API] Current user permissions: #{current_user&.permissions&.pluck(:name)}"
      Rails.logger.info "[CC_API] Available agent roles: #{agent_roles.pluck(:name)}"
      Rails.logger.info "[CC_API] Available customer roles: #{customer_roles.pluck(:name)}"
      Rails.logger.info "[CC_API] Current user has CC permissions: #{current_user&.permissions&.any? { |p| cc_permissions.include?(p.name) }}"
      Rails.logger.info "[CC_API] Admin exclusion applied: #{admin_role_ids.any? ? 'Yes' : 'No'}"
      Rails.logger.info "[CC_API] Total admin users excluded: #{admin_user_ids&.length || 0}"
    end

    # Apply pagination (ordering already applied above)
    users = query.limit(per_page)
                 .offset(offset)

    Rails.logger.info "[CC_API] Returning #{users.count} users (page #{page}/#{(total_count.to_f / per_page).ceil})"

    # Format response with pagination metadata and user type information
    users_list = users.map do |user|
      # Determine user type for frontend display (agents and customers only)
      # Check permissions in priority order: agent > customer
      user_type = if user.permissions.any? { |p| p.name == 'ticket.agent' }
                    'agent'
                  elsif user.permissions.any? { |p| p.name == 'ticket.customer' }
                    'customer'
                  else
                    'unknown'
                  end

      # Verify this user doesn't have admin permissions (double-check admin exclusion)
      has_admin_permissions = admin_role_ids.any? && user.roles.where(id: admin_role_ids).exists?

      if has_admin_permissions
        Rails.logger.warn "[CC_API] WARNING: User #{user.id} has admin permissions but appeared in results!"
        user_type = 'admin_excluded'
      end

      {
        id: user.id,
        login: user.login,
        firstname: user.firstname,
        lastname: user.lastname,
        email: user.email,
        active: user.active,
        user_type: user_type,
        roles: user.roles.pluck(:name),
        permissions: user.permissions.pluck(:name),
        has_admin_access: has_admin_permissions
      }
    end

    Rails.logger.info "[CC_API] User types in results (agents/customers only): #{users_list.map { |u| u[:user_type] }.uniq.inspect}"

    # Build pagination metadata with performance info
    total_pages = (total_count.to_f / per_page).ceil
    pagination_meta = {
      current_page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_next_page: page < total_pages,
      has_prev_page: page > 1,
      # Performance indicators
      large_dataset: total_count > 1000,
      search_mode: search_query.present?,
      optimized_for: search_query.present? ? 'search' : 'browsing',
      user_types: 'agents_and_customers_only',
      admin_exclusion_applied: admin_role_ids.any?,
      excluded_admin_count: admin_user_ids&.length || 0,
      cc_access_grants_ticket_access: true
    }

    Rails.logger.info "[CC_API] Pagination meta: #{pagination_meta.inspect}"
    Rails.logger.info "[CC_API] Performance: #{search_query.present? ? 'Search optimized' : 'Browse optimized'} query for agents/customers only"
    Rails.logger.info "[CC_API] Admin exclusion: Applied (excluded #{admin_role_ids.length} admin roles, #{admin_user_ids&.length || 0} admin users)"

    # Add cache headers for better performance (5 minute cache for non-search, 1 minute for search)
    cache_time = search_query.present? ? 1.minute : 5.minutes
    response.headers['Cache-Control'] = "public, max-age=#{cache_time.to_i}"

    # Return response with pagination metadata (agents and customers only)
    render json: {
      users: users_list,
      pagination: pagination_meta,
      performance: {
        query_time: Time.current,
        cache_suggestion: search_query.blank? ? 'Consider caching this result' : 'Search results not cached',
        user_filter: 'agents_and_customers_only',
        admin_exclusion_applied: admin_role_ids.any?,
        excluded_admin_count: admin_user_ids&.length || 0
      }
    }, status: :ok
  end
end

