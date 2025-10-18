# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    console.log('[CC_DEBUG] Rendering CC user select with searchable_select')
    console.log('[CC_DEBUG] App.User.all() before render:', App.User.all().length)
    console.log('[CC_DEBUG] App.User.all() users before render:', App.User.all())
    
    # Check if we need to load more users
    all_users = App.User.all()
    if all_users.length < 10
      console.log('[CC_DEBUG] Few users loaded, attempting to load more...')
      # Try to trigger loading more users
      App.User.fetch()
      console.log('[CC_DEBUG] After App.User.fetch():', App.User.all().length)
      
      # If still few users, try loading with different parameters
      if App.User.all().length < 10
        console.log('[CC_DEBUG] Still few users, trying to load with limit...')
        App.User.fetch(limit: 1000)
        console.log('[CC_DEBUG] After App.User.fetch(limit: 1000):', App.User.all().length)
    
    # SOLUTION: Use searchable_select with 'User' relation
    # This uses App.User.all() which is already loaded in frontend
    # No backend AJAX needed - avoids 403 permission issues for customers
    
    attribute.tag = 'searchable_select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Search for agents or customers...')
    
    # Apply custom filter to show only agents and customers (excluding current user)
    attribute.filter = (users) ->
      console.log('[CC_DEBUG] === FILTER FUNCTION CALLED ===')
      console.log('[CC_DEBUG] Total users passed to filter:', users.length)
      console.log('[CC_DEBUG] Users passed to filter:', users)
      console.log('[CC_DEBUG] App.User.all() count:', App.User.all().length)
      console.log('[CC_DEBUG] App.User.all() users:', App.User.all())
      
      current_user_id = App.User.current()?.id
      
      # Get Agent and Customer roles
      # ISSUE: Both roles have same ID (1) - they're the same role!
      # SOLUTION: Find roles by permissions instead of name
      agent_roles = App.Role.withPermissions('ticket.agent')
      customer_roles = App.Role.withPermissions('ticket.customer')
      
      agent_role = agent_roles[0] if agent_roles?.length > 0
      customer_role = customer_roles[0] if customer_roles?.length > 0
      
      # If not found by permissions, try by name as fallback
      if !agent_role
        agent_role = App.Role.findByAttribute('name', 'Agent')
      if !customer_role
        customer_role = App.Role.findByAttribute('name', 'Customer')
      
      console.log('[CC_DEBUG] Filtering users - Agent role:', agent_role?.id, 'Customer role:', customer_role?.id)
      console.log('[CC_DEBUG] Agent role object:', agent_role)
      console.log('[CC_DEBUG] Customer role object:', customer_role)
      console.log('[CC_DEBUG] All available roles:', App.Role.all())
      console.log('[CC_DEBUG] Roles with ticket.agent permission:', agent_roles)
      console.log('[CC_DEBUG] Roles with ticket.customer permission:', customer_roles)
      
      # Filter users
      filtered = []
      for user in users
        continue if user.id is current_user_id
        continue if !user.active
        
        # Check if user has Agent or Customer role
        # If role_ids is not available (permission issue), show all active users
        if !user.role_ids || user.role_ids.length == 0
          # Permission issue - can't see role_ids, so include all active users
          console.log('[CC_DEBUG] User', user.login, 'has no role_ids - including (permission issue)')
          filtered.push(user)
          continue
        
        console.log('[CC_DEBUG] User', user.login, 'role_ids:', user.role_ids)
        
        has_agent_role = agent_role && agent_role.id in user.role_ids
        has_customer_role = customer_role && customer_role.id in user.role_ids
        
        console.log('[CC_DEBUG] User', user.login, 'has_agent_role:', has_agent_role, 'has_customer_role:', has_customer_role)
        
        if has_agent_role || has_customer_role
          console.log('[CC_DEBUG] User', user.login, 'included in results')
          filtered.push(user)
        else
          console.log('[CC_DEBUG] User', user.login, 'excluded - no matching roles')
      
      console.log('[CC_DEBUG] Filtered', filtered.length, 'users from', users.length, 'total')
      filtered
    
    # Use searchable_select renderer
    App.UiElement.searchable_select.render(attribute, params)

# This uses searchable_select with 'User' relation (frontend data)
# No backend AJAX needed - works for customers and agents
# The filter function handles role filtering
# searchable_select provides built-in search functionality
