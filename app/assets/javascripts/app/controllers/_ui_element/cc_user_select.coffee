# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Follow approval modal pattern:
    # 1. Simple select tag (multiselect)
    # 2. Load users via AJAX with role filtering
    # 3. Build options hash for the select
    
    attribute.tag = 'select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.nulloption = false
    
    # Get Agent and Customer role IDs for backend filtering
    agent_roles = App.Role.withPermissions('ticket.agent')
    customer_roles = App.Role.withPermissions('ticket.customer')
    
    role_ids = []
    role_ids.push(agent_roles[0].id) if agent_roles?.length > 0
    role_ids.push(customer_roles[0].id) if customer_roles?.length > 0
    
    # Get current user to exclude
    current_user_id = App.User.current()?.id
    
    # Load users via AJAX
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/users"
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
        
        # Re-render the select with loaded users
        $element = $(element)
        new_element = App.UiElement.select.render(attribute, params)
        $element.replaceWith(new_element)
        
      error: (xhr, status, error) =>
        # Fallback: show all active users from App.User.all()
        all_users = App.User.all()
        attribute.options = {}
        for user_id, user of all_users
          continue if user.id is current_user_id
          continue if !user.active
          
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          attribute.options[user.id] = display_name
        
        # Re-render the select with fallback users
        $element = $(element)
        new_element = App.UiElement.select.render(attribute, params)
        $element.replaceWith(new_element)
    )
    
    # Start with empty options - will be populated by AJAX
    attribute.options = {}
    element = App.UiElement.select.render(attribute, params)
    element

# CC user select component
# - Loads agents and customers via AJAX
# - Excludes current user
# - Shows only active users
# - Multiselect dropdown for ticket creation
