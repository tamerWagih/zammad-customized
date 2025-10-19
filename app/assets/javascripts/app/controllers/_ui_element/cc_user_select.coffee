# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    console.log '[CC] Rendering CC user select'
    
    # Load users via AJAX call to /users/search (same as approval modal)
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Search for users to CC...')
    
    # Get role IDs for agents and customers (same pattern as approval)
    agent_roles = App.Role.withPermissions('ticket.agent')
    customer_roles = App.Role.withPermissions('ticket.customer')
    
    console.log '[CC] Agent roles:', agent_roles?.length || 0
    console.log '[CC] Customer roles:', customer_roles?.length || 0
    
    role_ids = []
    if agent_roles
      for role in agent_roles
        role_ids.push(role.id)
    if customer_roles
      for role in customer_roles
        role_ids.push(role.id)
    role_ids = _.uniq(role_ids) # Remove duplicates
    
    console.log '[CC] Role IDs to search:', role_ids
    
    # Start with empty options
    attribute.options = {}
    
    current_user_id = App.User.current()?.id
    console.log '[CC] Current user ID:', current_user_id
    
    # Make AJAX call using App.Ajax (same as approval modal uses @ajax)
    App.Ajax.request(
      id: 'cc_users_search'
      type: 'GET'
      url: "#{App.Config.get('api_path')}/users/search"
      data:
        role_ids: role_ids
        limit: 1000
      processData: true
      success: (data, status, xhr) =>
        console.log '[CC] Users loaded successfully'
        console.log '[CC] Raw data:', data
        console.log '[CC] Data type:', typeof data
        console.log '[CC] Is array?:', Array.isArray(data)
        users = if Array.isArray(data) then data else (data?.users || [])
        console.log '[CC] Total users received:', users.length
        
        # Build options (same filtering as approval)
        attribute.options = {}
        filtered_count = 0
        for user in users
          # Exclude current user (convert to string for comparison)
          if user.id.toString() == current_user_id.toString()
            console.log '[CC] Excluding current user:', user.id
            continue
          # Exclude inactive users
          if !user.active
            console.log '[CC] Excluding inactive user:', user.id
            continue
          
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          if user.email && display_name != user.email
            display_name += " (#{user.email})"
          
          attribute.options[user.id] = display_name
          filtered_count++
        
        console.log '[CC] Filtered users for dropdown:', filtered_count
        console.log '[CC] Options:', Object.keys(attribute.options).length
        
        # Re-render with loaded users
        $element = $(element)
        new_element = App.UiElement.searchable_select.render(attribute, params)
        $element.replaceWith(new_element)
        console.log '[CC] Dropdown re-rendered with users'
        
      error: (xhr, status, error) =>
        console.error '[CC] Failed to load users'
        console.error '[CC] Status:', status
        console.error '[CC] Error:', error
        console.error '[CC] XHR:', xhr
        
        # Fallback to empty
        attribute.options = {}
        $element = $(element)
        new_element = App.UiElement.searchable_select.render(attribute, params)
        $element.replaceWith(new_element)
    )
    
    # Render initial element (will be replaced after AJAX completes)
    element = App.UiElement.searchable_select.render(attribute, params)
    console.log '[CC] Initial element rendered (empty)'
    element
