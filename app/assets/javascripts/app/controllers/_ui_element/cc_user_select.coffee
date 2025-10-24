# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Follow Zammad's standard pattern: Use relation with filter function
    # This is how Zammad handles filtered dropdowns (like timezone, locale)
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = 'User'  # Use User relation so searchable_select can load from cache
    attribute.placeholder = __('Select users to CC...')
    
    # CRITICAL: Use filter function to exclude current user and non-agent/customer users
    # This follows Zammad's standard pattern (see _application_ui_element.coffee line 117)
    currentUserId = App.Session.get('id')
    
    attribute.filter = (items) ->
      console.log "[CC_USERS] Filtering #{items.length} users from User model cache"
      console.log "[CC_USERS] Current user to exclude: #{currentUserId}"
      
      filtered = []
      for user in items
        # Exclude current user
        if user.id == currentUserId
          console.log "[CC_USERS] Excluding current user #{user.id} (#{user.login})"
          continue
        
        # Only include agents and customers (exclude admins without agent permission)
        isAgent = user.permissions?('ticket.agent')
        isCustomer = user.permissions?('ticket.customer')
        
        unless isAgent || isCustomer
          console.log "[CC_USERS] Excluding #{user.id} (#{user.login}) - no agent/customer permission"
          continue
        
        # Include this user
        filtered.push user
      
      console.log "[CC_USERS] Filtered to #{filtered.length} users (agents and customers only)"
      filtered
    
    # Render searchable_select (it will call getRelationOptionList with our filter)
    console.log "[CC_USERS] Rendering CC dropdown with User relation + filter"
    element = App.UiElement.searchable_select.render(attribute, params)
    
    console.log "[CC_USERS] CC dropdown rendered successfully"
    element
