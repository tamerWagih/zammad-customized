# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    console.log('[CC_DEBUG] Rendering CC user select with searchable_select')
    
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
      current_user_id = App.User.current()?.id
      
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
      
      console.log('[CC_DEBUG] Filtering users - Agent role:', agent_role?.id, 'Customer role:', customer_role?.id)
      
      # Filter users
      filtered = []
      for user in users
        continue if user.id is current_user_id
        continue if !user.active
        
        # Check if user has Agent or Customer role
        # If role_ids is not available (permission issue), show all active users
        if !user.role_ids || user.role_ids.length == 0
          # Permission issue - can't see role_ids, so include all active users
          filtered.push(user)
          continue
        
        has_agent_role = agent_role && agent_role.id in user.role_ids
        has_customer_role = customer_role && customer_role.id in user.role_ids
        
        if has_agent_role || has_customer_role
          filtered.push(user)
      
      console.log('[CC_DEBUG] Filtered', filtered.length, 'users from', users.length, 'total')
      filtered
    
    # Use searchable_select renderer
    App.UiElement.searchable_select.render(attribute, params)

# This uses searchable_select with 'User' relation (frontend data)
# No backend AJAX needed - works for customers and agents
# The filter function handles role filtering
# searchable_select provides built-in search functionality
