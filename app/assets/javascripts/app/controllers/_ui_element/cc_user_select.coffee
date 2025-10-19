# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # FINAL SOLUTION: Use searchable_select with /users/search (now accessible to customers)
    # Backend modified to allow customers to search for agents/customers
    
    attribute.tag = 'searchable_select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Search for users to CC...')
    
    # Enable AJAX mode to load users on demand from backend (/users/search)
    attribute.ajax = true
    
    # Get Agent and Customer role IDs to pass to backend
    agent_roles = App.Role.withPermissions('ticket.agent')
    customer_roles = App.Role.withPermissions('ticket.customer')
    
    role_ids = []
    if agent_roles
      for role in agent_roles
        role_ids.push(role.id)
    if customer_roles
      for role in customer_roles
        role_ids.push(role.id)
    
    # Pass role_ids to backend search (filters for agents/customers only)
    attribute.params =
      role_ids: role_ids
      limit: 1000
    
    # Custom filter to exclude current user on frontend
    attribute.filter = (users) ->
      current_user_id = App.User.current()?.id
      
      filtered = []
      for user in users
        # Exclude current user
        continue if user.id is current_user_id
        
        # Exclude inactive users (belt-and-suspenders - backend should already filter)
        continue if !user.active
        
        filtered.push(user)
      
      filtered
    
    # Use searchable_select renderer
    App.UiElement.searchable_select.render(attribute, params)

# CC user select component
# - Uses searchable_select with 'User' relation and AJAX mode
# - Calls /users/search with role_ids for agents/customers
# - UsersController.authorize_search now allows customers to search
# - Shows ALL agents and customers (loaded via AJAX, not just cached)
# - Handles large numbers of users with pagination and search
# - Frontend filter excludes current user only
