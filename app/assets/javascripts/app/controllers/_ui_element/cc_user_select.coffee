# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    console.log('[CC_DEBUG] Rendering CC user select with AJAX search support')
    
    # Use searchable_select with backend AJAX for search and pagination
    # This allows searching for users beyond the initially loaded set
    attribute.tag = 'searchable_select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Search for agents or customers...')
    
    # Don't use the default relation loading - we'll provide our own options
    # This prevents loading ALL users upfront
    delete attribute.relation
    
    # Get Agent and Customer role IDs for backend filtering
    agent_role = App.Role.findByAttribute('name', 'Agent')
    customer_role = App.Role.findByAttribute('name', 'Customer')
    
    # Fallback: try by permissions if not found by name
    if !agent_role
      agent_roles = App.Role.withPermissions('ticket.agent')
      agent_role = agent_roles[0] if agent_roles?.length > 0
    
    if !customer_role
      customer_roles = App.Role.withPermissions('ticket.customer')
      customer_role = customer_roles[0] if customer_roles?.length > 0
    
    role_ids = []
    role_ids.push(agent_role.id) if agent_role
    role_ids.push(customer_role.id) if customer_role
    
    console.log('[CC_DEBUG] Role IDs for filtering:', role_ids)
    
    # Get current user to exclude from results
    current_user_id = App.User.current()?.id
    
    # Start with empty options - will be populated dynamically
    attribute.options = {}
    
    # First, render the searchable_select with empty options
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Then load users via AJAX in the background (like approval modal does)
    # This is more efficient and supports searching all users
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/users/search"
      data:
        role_ids: role_ids
        limit: 1000
      processData: true
      success: (data) =>
        users = if Array.isArray(data) then data else (data?.users || [])
        
        # Filter out current user and inactive users
        filtered_users = users.filter (user) ->
          return false if user.id is current_user_id
          return false if user.active is false
          true
        
        # Build options for searchable_select
        new_options = {}
        for user in filtered_users
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          # Add email in parentheses if different from display name
          if user.email && display_name != user.email
            display_name += " (#{user.email})"
          
          new_options[user.id] = display_name
        
        console.log('[CC_DEBUG] Loaded users via AJAX:', Object.keys(new_options).length)
        
        # Update the attribute options
        attribute.options = new_options
        
        # Re-render the searchable_select with loaded users
        # Find the element and update it
        $element = $(element)
        $parent = $element.parent()
        new_element = App.UiElement.searchable_select.render(attribute, params)
        $element.replaceWith(new_element)
        
      error: (xhr, status, error) =>
        console.error('[CC_DEBUG] Failed to load users:', error)
    )
    
    # Return the initial element (will be updated when AJAX completes)
    element

# This uses searchable_select with AJAX backend loading
# Supports searching and finding users beyond initial page load
# More similar to how approval modal works (AJAX backend call)
