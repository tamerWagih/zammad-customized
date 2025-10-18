# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    console.log('[CC_DEBUG] Rendering CC user select with attribute:', attribute)
    
    # Use native searchable_select structure with custom relation filtering
    attribute.tag = 'searchable_select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.placeholder = __('Search for users...')
    # Don't load all users upfront to avoid performance issues
    attribute.ajax = true
    attribute.filter = (users, type, params) ->
      console.log('[CC_DEBUG] Filter called with users:', users.length)
      
      # The issue: App.User.search() returns minimal data without permissions
      # We need to get full user objects with permissions
      current_user_id = App.User.current()?.id
      console.log('[CC_DEBUG] Current user ID:', current_user_id)
      
      # Get full user objects from App.User.all() 
      all_users = App.User.all()
      console.log('[CC_DEBUG] All users from App.User.all():', all_users.length)
      
      # Get Agent and Customer roles
      agent_role = App.Role.findByAttribute('name', 'Agent')
      customer_role = App.Role.findByAttribute('name', 'Customer')
      console.log('[CC_DEBUG] Agent role:', agent_role)
      console.log('[CC_DEBUG] Customer role:', customer_role)
      
      # Filter to only show agents and customers, exclude current user
      filtered_users = []
      for user_id, user of all_users
        console.log('[CC_DEBUG] Checking user:', user.login, 'ID:', user.id, 'Active:', user.active)
        console.log('[CC_DEBUG] User role_ids:', user.role_ids)
        
        continue if user.id is current_user_id
        continue if !user.active
        
        # Check if user has Agent or Customer role
        has_agent_role = agent_role && user.role_ids && user.role_ids.includes(agent_role.id)
        has_customer_role = customer_role && user.role_ids && user.role_ids.includes(customer_role.id)
        
        console.log('[CC_DEBUG] Has agent role:', has_agent_role)
        console.log('[CC_DEBUG] Has customer role:', has_customer_role)
        
        if has_agent_role || has_customer_role
          filtered_users.push(user)
      
      console.log('[CC_DEBUG] Filtered users:', filtered_users.length)
      console.log('[CC_DEBUG] Filtered users list:', filtered_users)
      return filtered_users
    
    # Use native searchable_select
    App.UiElement.searchable_select.render(attribute, params)

# This file now uses the native searchable_select component
# All the custom logic has been replaced with native Zammad functionality
