# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Hybrid approach: Small preload + backend search on demand
    # Best of both worlds: fast initial load + unlimited searchability
    
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
        
        for user in users
          # CRITICAL: Compare as strings to avoid type mismatch issues
          continue if String(user.id) == String(currentUserId)
          
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
        )
    
    # Configure searchable multi-select
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    # CRITICAL: Do NOT set relation = 'User' - it bypasses our filtered options!
    # We provide explicit options with current user already filtered out
    attribute.placeholder = __('Type to search users...')
    attribute.options = userOptions
    
    # Render with Zammad's standard searchable_select
    # CRITICAL: Don't populate App.User cache - it might cause searchable_select to reload users
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
          $.ajax(
            type: 'GET'
            url: "#{App.Config.get('api_path')}/tickets/cc_users?search=#{encodeURIComponent(query)}&per_page=100"
            success: (data) ->
              users = if data.users then data.users else data
              
              # Add new users to options
              for user in users
                # CRITICAL: Compare as strings to avoid type mismatch issues
                continue if String(user.id) == String(currentUserId)
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
    
    element
