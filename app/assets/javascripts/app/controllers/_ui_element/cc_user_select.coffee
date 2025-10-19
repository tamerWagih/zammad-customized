# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Load users via AJAX call to /users/search
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Search for users to CC...')
    
    # Get role IDs for agents and customers
    agent_roles = App.Role.withPermissions('ticket.agent')
    customer_roles = App.Role.withPermissions('ticket.customer')
    
    role_ids = []
    if agent_roles
      for role in agent_roles
        role_ids.push(role.id)
    if customer_roles
      for role in customer_roles
        role_ids.push(role.id)
    
    # Start with empty options
    attribute.options = {}
    
    current_user_id = App.User.current()?.id
    
    # Make AJAX call to load users
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/users/search"
      data:
        role_ids: role_ids
        limit: 1000
      processData: true
      success: (data) =>
        users = if Array.isArray(data) then data else (data?.users || [])
        
        # Build options
        attribute.options = {}
        for user in users
          continue if user.id is current_user_id
          continue if !user.active
          
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          if user.email && display_name != user.email
            display_name += " (#{user.email})"
          
          attribute.options[user.id] = display_name
        
        # Re-render with loaded users
        $element = $(element)
        new_element = App.UiElement.searchable_select.render(attribute, params)
        $element.replaceWith(new_element)
        
      error: (xhr, status, error) =>
        console.error 'CC: Failed to load users', status, error
        # Fallback to empty
        attribute.options = {}
        $element = $(element)
        new_element = App.UiElement.searchable_select.render(attribute, params)
        $element.replaceWith(new_element)
    )
    
    # Render initial element
    element = App.UiElement.searchable_select.render(attribute, params)
    element
