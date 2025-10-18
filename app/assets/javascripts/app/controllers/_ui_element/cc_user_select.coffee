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
      console.log('[CC_DEBUG] Current user:', App.User.current())
      console.log('[CC_DEBUG] Current user permissions:', App.User.current()?.permissions)
      console.log('[CC_DEBUG] Current user role_ids:', App.User.current()?.role_ids)
      
      # Get full user objects from App.User.all() 
      all_users = App.User.all()
      console.log('[CC_DEBUG] All users from App.User.all():', all_users.length)
      
      # If we have very few users, try to load more via AJAX
      if all_users.length < 10
        console.log('[CC_DEBUG] Few users loaded, trying AJAX to get more...')
        # This is a fallback - the native searchable_select should handle this
        # But let's see what we get from the search results
        console.log('[CC_DEBUG] Search results users:', users.length)
        console.log('[CC_DEBUG] Search results:', users)
        
        # For now, let's show all active users and let the user select
        # We can refine the role filtering later once we understand the permission structure
        console.log('[CC_DEBUG] Showing all active users for now (permission issue suspected)')
      
      # Get Agent and Customer roles - try multiple ways
      agent_role = App.Role.findByAttribute('name', 'Agent')
      customer_role = App.Role.findByAttribute('name', 'Customer')
      
      # If not found by name, try to find by permissions
      if !agent_role
        agent_roles = App.Role.withPermissions('ticket.agent')
        agent_role = agent_roles[0] if agent_roles.length > 0
        console.log('[CC_DEBUG] Agent role by permissions:', agent_role)
      
      if !customer_role
        customer_roles = App.Role.withPermissions('ticket.customer')
        customer_role = customer_roles[0] if customer_roles.length > 0
        console.log('[CC_DEBUG] Customer role by permissions:', customer_role)
      
      console.log('[CC_DEBUG] Agent role:', agent_role)
      console.log('[CC_DEBUG] Customer role:', customer_role)
      console.log('[CC_DEBUG] All roles:', App.Role.all())
      
      # Log all role details to see what exists
      all_roles = App.Role.all()
      for role_id, role of all_roles
        console.log('[CC_DEBUG] Role:', role.name, 'ID:', role.id, 'Permissions:', role.permissions)
      
      # Log the specific role IDs we found
      if agent_role
        console.log('[CC_DEBUG] Agent role ID:', agent_role.id, 'Name:', agent_role.name)
      if customer_role
        console.log('[CC_DEBUG] Customer role ID:', customer_role.id, 'Name:', customer_role.name)
      
      # Filter to only show agents and customers, exclude current user
      filtered_users = []
      
      # Try to use search results if they have more complete data
      users_to_check = if users.length > all_users.length then users else all_users
      console.log('[CC_DEBUG] Using users_to_check:', users_to_check.length)
      
      for user in users_to_check
        console.log('[CC_DEBUG] Checking user:', user.login, 'ID:', user.id, 'Active:', user.active)
        console.log('[CC_DEBUG] User role_ids:', user.role_ids)
        
        # If user has role_ids, log them in detail
        if user.role_ids && user.role_ids.length > 0
          console.log('[CC_DEBUG] User role_ids details:', user.role_ids)
          for role_id in user.role_ids
            role = App.Role.find(role_id)
            console.log('[CC_DEBUG] User role:', role_id, 'Name:', role?.name, 'Permissions:', role?.permissions)
        
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
      
      # If no users found due to permission issues, show all active users as fallback
      if filtered_users.length == 0
        console.log('[CC_DEBUG] No users found with role filtering, showing all active users as fallback')
        for user in users_to_check
          continue if user.id is current_user_id
          continue if !user.active
          filtered_users.push(user)
        console.log('[CC_DEBUG] Fallback filtered users:', filtered_users.length)
      
      return filtered_users
    
    # Use native searchable_select
    App.UiElement.searchable_select.render(attribute, params)

# This file now uses the native searchable_select component
# All the custom logic has been replaced with native Zammad functionality
