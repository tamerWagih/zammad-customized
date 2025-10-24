# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Hybrid approach: Small preload + backend search on demand
    # Best of both worlds: fast initial load + unlimited searchability
    
    console.log "[CC_USERS] Rendering CC user select"
    currentUserId = App.Session.get('id')
    
    # Load initial 100 users for immediate dropdown (fast!)
    userOptions = []
    loadedUserIds = []
    
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users?per_page=100"
      async: false
      success: (data) ->
        users = if data.users then data.users else data
        console.log "[CC_USERS] Preloaded #{users.length} users"
        
          for user in users
          continue if user.id == currentUserId
          
          displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          displayName = user.login if displayName == ''
          
          if user.email
            displayName += " (#{user.email})"
          
          userOptions.push({
            value: user.id
            name: displayName
          })
          loadedUserIds.push(user.id)
    )
    
    # CRITICAL: Load selected users to show names (not IDs!)
    if params.cc_user_ids?.length > 0
      for userId in params.cc_user_ids
        continue if loadedUserIds.includes(userId)
        
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
            loadedUserIds.push(user.id)
            console.log "[CC_USERS] Loaded selected user #{user.id}: #{displayName}"
        )
    
    # Configure searchable multi-select
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = 'User'  # CRITICAL: Set relation so it uses cache for display names!
    attribute.placeholder = __('Type to search users...')
    attribute.options = userOptions
    
    # Ensure selected users are in App.User cache
    for option in userOptions
      if !App.User.exists(option.value)
        # Create minimal User object in cache
        App.User.refresh([{
          id: option.value
          firstname: option.name.split('(')[0].trim()
          lastname: ''
          login: option.name
          email: option.name.match(/\((.*?)\)/)?[1] || ''
        }], clear: false)
    
    # Render with Zammad's standard searchable_select
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Add backend search functionality
    searchInput = element.find('.js-input')
    searchTimer = null
    
    searchInput.on 'input', ->
      query = $(this).val().trim()
      return if query.length < 2
      
      clearTimeout(searchTimer) if searchTimer
      
      # Debounce 500ms
      searchTimer = setTimeout(->
        # Search backend if query not found in current options
        matchingOptions = userOptions.filter((opt) -> 
          opt.name.toLowerCase().includes(query.toLowerCase())
        )
        
        if matchingOptions.length == 0
          console.log "[CC_USERS] No match in preloaded users, searching backend for: #{query}"
          
          $.ajax(
            type: 'GET'
            url: "#{App.Config.get('api_path')}/tickets/cc_users?search=#{encodeURIComponent(query)}&per_page=100"
            success: (data) ->
              users = if data.users then data.users else data
              console.log "[CC_USERS] Backend search found #{users.length} users"
              
              # Add new users to options
              for user in users
                continue if user.id == currentUserId
                continue if loadedUserIds.includes(user.id)
                
                displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
                displayName = user.login if displayName == ''
                
                if user.email
                  displayName += " (#{user.email})"
                
                # Add to cache
                if !App.User.exists(user.id)
                  App.User.refresh([user], clear: false)
                
                loadedUserIds.push(user.id)
              
              # Trigger searchable_select to rebuild dropdown
              searchInput.trigger('change')
          )
      , 500)
    
    console.log "[CC_USERS] Rendered with #{userOptions.length} options + backend search"
    element
