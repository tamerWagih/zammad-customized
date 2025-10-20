# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Use synchronous pattern - load users first, then render
    # This is simpler and more reliable than async replacement
    
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
    
    # Build options - try to get from cached User collection first
    attribute.options = {}
    
    # Get users from User collection (cached in frontend)
    all_users = App.User.all()
    
    for user in all_users
      # Skip if not in target roles
      continue if !user.role_ids
      has_role = false
      for role_id in user.role_ids
        if role_id in role_ids
          has_role = true
          break
      continue if !has_role
      
      # Skip current user and inactive users
      continue if user.id.toString() == current_user_id.toString()
      continue if !user.active
      
      display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
      display_name = user.login if display_name == ''
      display_name = user.email if !display_name
      display_name = "User ##{user.id}" if !display_name
      
      if user.email && display_name != user.email
        display_name += " (#{user.email})"
      
      attribute.options[user.id] = display_name
    
    # Render the searchable select with the options
    App.UiElement.searchable_select.render(attribute, params)
