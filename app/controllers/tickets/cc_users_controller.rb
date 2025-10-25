# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Tickets::CcUsersController < ApplicationController
  prepend_before_action :authentication_check

  # GET /api/v1/tickets/cc_users
  # Use Zammad's native search but FILTER OUT current user in results
  def index
    # Use Zammad's native User.search (same as /users/search)
    paginate_with(max: 200, default: 50)
    
    search_results = User.search(
      query:            params[:query] || params[:term],
      permissions:      ['ticket.agent', 'ticket.customer'],
      only_total_count: false,
      limit:            pagination.limit,
      offset:           pagination.offset,
      current_user:     current_user,
      full:             true,
      with_total_count: true,
    ) || { objects: [], total_count: 0 }
    
    # CRITICAL: Filter out current user from results
    filtered_objects = search_results[:objects].reject { |u| u.id == current_user.id }
    
    # Format as label/value for autocomplete (same format as UsersController)
    result = filtered_objects.map do |user|
      realname = user.fullname(recipient_line: true) || user.fullname || user.login
      value = user.email || realname
      { id: user.id, label: realname, value: value, inactive: !user.active }
    end
    
    render json: result, status: :ok
  end
end
