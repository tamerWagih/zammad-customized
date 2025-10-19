# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Use searchable_select with AJAX to load all users dynamically
    # This ensures we get ALL users, not just the initially cached ones
    
    attribute.tag = 'searchable_select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Search for users to CC...')
    
    # Enable AJAX mode to load users on demand from backend
    attribute.ajax = true
    
    # Custom filter to show only agents and customers (excluding current user)
    attribute.filter = (users) ->
      current_user_id = App.User.current()?.id
      
      # Get Agent and Customer roles
      agent_roles = App.Role.withPermissions('ticket.agent')
      customer_roles = App.Role.withPermissions('ticket.customer')
      
      agent_role_ids = (role.id for role in agent_roles) if agent_roles
      customer_role_ids = (role.id for role in customer_roles) if customer_roles
      all_role_ids = []
      all_role_ids = all_role_ids.concat(agent_role_ids) if agent_role_ids
      all_role_ids = all_role_ids.concat(customer_role_ids) if customer_role_ids
      
      # Filter users
      filtered = []
      for user in users
        continue if user.id is current_user_id
        continue if !user.active
        
        # If user has role_ids, check if they have Agent or Customer role
        if user.role_ids && user.role_ids.length > 0
          has_role = false
          for role_id in user.role_ids
            if role_id in all_role_ids
              has_role = true
              break
          continue if !has_role
        
        filtered.push(user)
      
      filtered
    
    # Use searchable_select renderer
    App.UiElement.searchable_select.render(attribute, params)

# CC user select component
# - Uses searchable_select with 'User' relation, AJAX mode, and custom filter
# - Shows agents and customers (excluding current user)
# - Loads users dynamically via AJAX (not just cached users)
# - Handles large numbers of users with search
