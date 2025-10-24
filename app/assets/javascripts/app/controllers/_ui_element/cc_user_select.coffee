# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Simple, reliable searchable multi-select
    # Loads up to 5000 users upfront, searchable_select handles search client-side
    
    console.log "[CC_USERS] Rendering CC user select"
    currentUserId = App.Session.get('id')
    
    # Load users from backend
    userOptions = []
    loadedUserIds = []
    
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users?per_page=5000"
      async: false
      success: (data) ->
        users = if data.users then data.users else data
        console.log "[CC_USERS] Loaded #{users.length} users"
        
        for user in users
          continue if user.id == currentUserId
          
          # Build display: Name (email) - NO role!
          displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          displayName = user.login if displayName == ''
          
          if user.email
            displayName += " (#{user.email})"
          
          userOptions.push({
            value: user.id
            name: displayName
          })
          loadedUserIds.push(user.id)
      
      error: ->
        console.error "[CC_USERS] Failed to load users"
    )
    
    # CRITICAL: If editing, load selected users that might not be in first 5000
    if params.cc_user_ids?.length > 0
      for userId in params.cc_user_ids
        continue if loadedUserIds.includes(userId)
        
        # Load this specific user to show their name (not ID)
        $.ajax(
          type: 'GET'
          url: "#{App.Config.get('api_path')}/users/#{userId}"
          async: false
          success: (user) ->
            displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
            displayName = user.login if displayName == ''
            
            if user.email
              displayName += " (#{user.email})"
            
            userOptions.push({
              value: user.id
              name: displayName
            })
            console.log "[CC_USERS] Loaded selected user #{user.id}: #{displayName}"
        )
    
    # Configure searchable multi-select
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''
    attribute.placeholder = __('Type to search users...')
    attribute.options = userOptions
    
    # Render with Zammad's standard searchable_select
    element = App.UiElement.searchable_select.render(attribute, params)
    
    console.log "[CC_USERS] Rendered with #{userOptions.length} options"
    element
