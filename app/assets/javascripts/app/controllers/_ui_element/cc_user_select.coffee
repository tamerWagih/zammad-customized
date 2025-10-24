# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # PROPER APPROACH (like Approval Request Modal):
    # 1. Load ALL agents/customers from backend API
    # 2. Build options object
    # 3. Render searchable_select with options
    # 
    # DON'T use relation='User' - cache doesn't have all users!
    # (Only has users from current session activities)
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''  # Empty - we provide explicit options
    attribute.placeholder = __('Loading users...')
    
    console.log "[CC_USERS] Loading CC users from backend API"
    
    # Load users synchronously from our dedicated endpoint
    options = []  # CRITICAL: Array, not object!
    currentUserId = App.Session.get('id')
    
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      async: false  # Synchronous to get all users before rendering
      success: (data) ->
        users = if data.users then data.users else data
        console.log "[CC_USERS] Loaded #{users?.length || 0} users from API"
        
        if users && users.length > 0
          for user in users
            # Skip current user (backend should already exclude, but safety check)
            continue if user.id == currentUserId
            
            # Build display name
            display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
            display_name = user.login if display_name == ''
            display_name = user.email if !display_name
            
            # Add user type and email
            user_type = if user.user_type == 'agent' then 'Agent' else 'Customer'
            if user.email
              display_name += " (#{user.email}) [#{user_type}]"
            else
              display_name += " [#{user_type}]"
            
            # CRITICAL: Push as object with 'value' and 'name' (searchable_select format)
            options.push({
              value: user.id.toString()
              name: display_name
            })
          
          console.log "[CC_USERS] Built #{options.length} options from API"
      error: (xhr) ->
        console.error "[CC_USERS] Failed to load users:", xhr.status
        # Leave options empty
    )
    
    # Set options and render
    if options.length > 0
      attribute.options = options
      attribute.placeholder = __('Select users to CC...')
      console.log "[CC_USERS] Rendering with #{options.length} users"
    else
      attribute.options = []
      attribute.placeholder = __('No users available')
      console.log "[CC_USERS] No users available"
    
    # Render searchable_select with all options
    element = App.UiElement.searchable_select.render(attribute, params)
    
    console.log "[CC_USERS] CC dropdown rendered"
    element
