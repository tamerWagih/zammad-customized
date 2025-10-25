# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Tickets::CcUsersController < ApplicationController
  prepend_before_action :authentication_check

  # GET /api/v1/tickets/cc_users
  # Use Zammad's native /users/search endpoint with custom exclusion filter
  # This is a WRAPPER that adds "exclude current user" logic
  def index
    # Delegate to native User.search with exclusion
    params[:exclude_ids] = [current_user.id]  # Exclude current user
    params[:permissions] = ['ticket.agent', 'ticket.customer']  # Only agents/customers
    
    # Use Zammad's native model_search_render (same as UsersController)
    model_search_render(User, params)
  end
end
