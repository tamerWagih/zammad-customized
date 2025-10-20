# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Use the same pattern as other searchable selects but with proper async user loading
    # This follows Zammad's standard pattern for remote data loading
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Search for users to CC...')
    attribute.relation = 'User'
    
    # Get current user to exclude from list
    current_user_id = App.User.current()?.id
    
    # Get role IDs for agents and customers
    agent_roles = App.Role.withPermissions('ticket.agent')
    customer_roles = App.Role.withPermissions('ticket.customer')
    
    role_ids = []
    if agent_roles
      role_ids = role_ids.concat(agent_roles.map (role) -> role.id)
    if customer_roles
      role_ids = role_ids.concat(customer_roles.map (role) -> role.id)
    role_ids = _.uniq(role_ids)
    
    # Build options from AJAX call
    attribute.options = {}
    
    # Create a wrapper to handle async loading
    wrapper = $('<div class="cc-user-select-wrapper"></div>')
    placeholder = $('<div class="loading">Loading users...</div>')
    wrapper.append(placeholder)
    
    # Load users via AJAX (same pattern as approval modal)
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/users/search"
      data:
        role_ids: role_ids
        limit: 1000
      dataType: 'json'
      success: (data, status, xhr) =>
        # Parse response (could be array or object with users key)
        users = if Array.isArray(data) then data else (data?.users || data?.records || [])
        
        # Build options, excluding current user and inactive users
        for user in users
          continue if user.id.toString() == current_user_id.toString()
          continue if !user.active
          
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          if user.email && display_name != user.email
            display_name += " (#{user.email})"
          
          attribute.options[user.id] = display_name
        
        # Replace placeholder with actual select element
        element = App.UiElement.searchable_select.render(attribute, params)
        wrapper.find('.loading').replaceWith(element)
        
      error: (xhr, status, error) =>
        console.error '[CC] Failed to load users:', error
        # Still render select but with empty options
        element = App.UiElement.searchable_select.render(attribute, params)
        wrapper.find('.loading').replaceWith(element)
    )
    
    wrapper[0]
