# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # PROVEN WORKING APPROACH FROM COMMIT 387daf48ed
    # Load ALL users from backend, build options, render searchable_select
    # FIX: Also load selected user data to show names not IDs
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''  # CRITICAL: Empty, NOT 'User'!
    attribute.placeholder = __('Loading users...')
    
    # Load users from backend API
    options = {}
    currentUserId = App.Session.get('id')
    
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      data:
        per_page: 200  # Get first 200 users (no search filter = all users)
      async: false
      success: (data) ->
        users = if data.users then data.users else data
        
        if users && users.length > 0
          for user in users
            # Skip current user (backend should already exclude)
            continue if user.id == currentUserId
            
            # Build display name
            display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
            display_name = user.login if display_name == ''
            display_name = user.email if !display_name
            
            # Add email and type
            user_type = if user.user_type == 'agent' then 'Agent' else 'Customer'
            if user.email
              display_name += " (#{user.email}) [#{user_type}]"
            else
              display_name += " [#{user_type}]"
            
            # Store as string key (required by searchable_select)
            options[user.id.toString()] = display_name
            
            # FIX: Ensure user is in App.User cache to show name not ID
            if !App.User.exists(user.id)
              App.User.refresh([{
                id: user.id
                firstname: user.firstname
                lastname: user.lastname
                login: user.login
                email: user.email
                active: user.active
              }], clear: false)
    )
    
    # FIX: Load selected users to ensure they show names not IDs
    # This handles the case where a ticket is being edited with existing CCs
    if params.cc_user_ids && params.cc_user_ids.length > 0
      for userId in params.cc_user_ids
        # Skip if already loaded
        continue if options[userId.toString()]
        
        # Fetch user data
        $.ajax(
          url: "#{App.Config.get('api_path')}/users/#{userId}"
          async: false
          success: (user) ->
            # Add to options
            display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
            display_name = user.login if display_name == ''
            display_name += " (#{user.email})" if user.email
            
            options[user.id.toString()] = display_name
            
            # Add to cache
            if !App.User.exists(user.id)
              App.User.refresh([user], clear: false)
        )
    
    # Set options
    attribute.options = options
    attribute.placeholder = if Object.keys(options).length > 0 then __('Select users to CC...') else __('No users available')
    
    # Render searchable_select
    element = App.UiElement.searchable_select.render(attribute, params)
    
    element
