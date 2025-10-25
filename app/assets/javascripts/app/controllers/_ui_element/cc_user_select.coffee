# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    
    # SIMPLE APPROACH: Pure backend search, no preloading
    # User must type at least 2 characters to search
    
    # Configure for backend AJAX search
    attribute.placeholder = __('Type to search users (min 2 chars)...')
    attribute.nulloption = false
    attribute.options = []  # No preloaded options
    attribute.minLenght = 2
    
    # Configure AJAX endpoint
    attribute.ajax = true
    attribute.searchUrl = "#{App.Config.get('api_path')}/tickets/cc_users"
    
    # Render standard searchable_select (handles AJAX automatically)
    element = App.UiElement.searchable_select.render(attribute, params)
    
    element
