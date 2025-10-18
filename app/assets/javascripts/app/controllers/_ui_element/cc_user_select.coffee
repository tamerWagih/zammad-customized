# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    console.log('[CC_DEBUG] Rendering CC user select - APPROVAL PATTERN')
    
    # SOLUTION: Follow approval modal pattern exactly
    # 1. Use simple 'select' tag (not searchable_select)
    # 2. Load users via AJAX with role filtering
    # 3. Build options hash for the select
    
    attribute.tag = 'select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.nulloption = false
    
    # Get Agent and Customer role IDs
    agent_roles = App.Role.withPermissions('ticket.agent')
    customer_roles = App.Role.withPermissions('ticket.customer')
    
    role_ids = []
    role_ids.push(agent_roles[0].id) if agent_roles?.length > 0
    role_ids.push(customer_roles[0].id) if customer_roles?.length > 0
    
    console.log('[CC_DEBUG] Role IDs for CC:', role_ids)
    
    # Get current user to exclude
    current_user_id = App.User.current()?.id
    
    # Load users via AJAX (like approval modal does)
    # This should work for customers since we're not using /users/search
    $.ajax(
        type: 'GET'
      url: "#{App.Config.get('api_path')}/users"
        data:
        role_ids: role_ids
          limit: 1000
        processData: true
      success: (data) =>
        users = if Array.isArray(data) then data else (data?.users || [])
        console.log('[CC_DEBUG] AJAX loaded users:', users.length)
        console.log('[CC_DEBUG] AJAX loaded users data:', users)
        console.log('[CC_DEBUG] Current user ID to exclude:', current_user_id)
        
        # Filter out current user and inactive users
        filtered_users = users.filter (user) ->
          console.log('[CC_DEBUG] Checking user:', user.login, 'ID:', user.id, 'Active:', user.active, 'Is current user:', (user.id is current_user_id))
          return false if user.id is current_user_id
          return false if user.active is false
          true
        
        console.log('[CC_DEBUG] After filtering - users count:', filtered_users.length)
        console.log('[CC_DEBUG] After filtering - users:', filtered_users)
        
        # Build options for select
        attribute.options = {}
        for user in filtered_users
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          # Add email in parentheses if different from display name
          if user.email && display_name != user.email
            display_name += " (#{user.email})"
          
          attribute.options[user.id] = display_name
        
        console.log('[CC_DEBUG] Built options for select:', Object.keys(attribute.options).length)
        
        # Re-render the select with loaded users
        $element = $(element)
        new_element = App.UiElement.select.render(attribute, params)
        $element.replaceWith(new_element)
        
      error: (xhr, status, error) =>
        console.error('[CC_DEBUG] Failed to load users via AJAX:', error)
        console.error('[CC_DEBUG] XHR status:', xhr.status)
        console.error('[CC_DEBUG] XHR response:', xhr.responseText)
        console.error('[CC_DEBUG] Status:', status)
        
        # Fallback: show all active users from App.User.all()
        console.log('[CC_DEBUG] Using fallback - App.User.all()')
        all_users = App.User.all()
        console.log('[CC_DEBUG] App.User.all() count:', all_users.length)
        
        attribute.options = {}
        for user_id, user of all_users
          console.log('[CC_DEBUG] Fallback checking user:', user?.login, 'ID:', user?.id, 'Active:', user?.active)
          continue if user.id is current_user_id
          continue if !user.active
          
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          attribute.options[user.id] = display_name
        
        console.log('[CC_DEBUG] Fallback options:', Object.keys(attribute.options).length)
        
        # Re-render the select with fallback users
        $element = $(element)
        new_element = App.UiElement.select.render(attribute, params)
        $element.replaceWith(new_element)
    )
    
    # Start with empty options - will be populated by AJAX
    attribute.options = {}
    element = App.UiElement.select.render(attribute, params)
    element

# This follows the approval modal pattern exactly:
# 1. Simple select tag (not searchable_select)
# 2. AJAX backend call to load users
# 3. Build options hash for the select
# 4. Fallback to App.User.all() if AJAX fails
