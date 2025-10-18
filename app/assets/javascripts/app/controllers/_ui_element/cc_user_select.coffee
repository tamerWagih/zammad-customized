# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    console.log('[CC_DEBUG] Rendering CC user select - using simple select tag (approval pattern)')
    
    # SOLUTION: Use simple 'select' tag like approval uses <select> in its template
    # The searchable_select was causing issues because it doesn't work well with inline ticket form
    # Approval modal uses a simple <select> dropdown rendered in a template, not searchable_select!
    
    attribute.tag = 'select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.nulloption = false
    
    # Get Agent and Customer roles
    agent_role = App.Role.findByAttribute('name', 'Agent')
    customer_role = App.Role.findByAttribute('name', 'Customer')
    
    # Fallback: try by permissions if not found by name
    if !agent_role
      agent_roles = App.Role.withPermissions('ticket.agent')
      agent_role = agent_roles[0] if agent_roles?.length > 0
    
    if !customer_role
      customer_roles = App.Role.withPermissions('ticket.customer')
      customer_role = customer_roles[0] if customer_roles?.length > 0
    
    console.log('[CC_DEBUG] Agent role:', agent_role)
    console.log('[CC_DEBUG] Customer role:', customer_role)
    
    # Filter users to only show agents and customers
    current_user_id = App.User.current()?.id
    all_users = App.User.all()
    
    filtered_users = []
    for user_id, user of all_users
      continue if user.id is current_user_id
      continue if !user.active
      
      # Check if user has Agent or Customer role
      has_agent_role = agent_role && user.role_ids && agent_role.id in user.role_ids
      has_customer_role = customer_role && user.role_ids && customer_role.id in user.role_ids
      
      if has_agent_role || has_customer_role
        filtered_users.push(user)
    
    console.log('[CC_DEBUG] Filtered users for select:', filtered_users.length)
    
    # If no users found (permission issue), show all active users
    if filtered_users.length == 0
      console.log('[CC_DEBUG] No users with roles found, showing all active users')
      for user_id, user of all_users
        continue if user.id is current_user_id
        continue if !user.active
        filtered_users.push(user)
    
    # Create options for the select
    attribute.options = {}
    for user in filtered_users
      display_name = "#{user.firstname} #{user.lastname}".trim()
      display_name = user.login if display_name == ''
      display_name = user.email if !display_name
      attribute.options[user.id] = display_name || "User ##{user.id}"
    
    console.log('[CC_DEBUG] Select options count:', Object.keys(attribute.options).length)
    
    # Use standard select renderer
    App.UiElement.select.render(attribute, params)

# This follows the approval pattern more closely
# Approval uses a simple <select> in the template, not searchable_select
