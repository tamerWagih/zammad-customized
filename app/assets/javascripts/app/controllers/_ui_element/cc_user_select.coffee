# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    
    # Get current user ID
    currentUserId = String(App.Session.get('id'))
    
    # CRITICAL: Configure for multi-select
    attribute.multiple = true
    attribute.tag = 'multiselect'
    attribute.placeholder = __('Type to search users (min 2 chars)...')
    attribute.nulloption = false
    
    # Start with empty options - will populate via search
    attribute.options = []
    
    # If there are pre-selected cc_user_ids, load their data to show NAMES not IDs
    if params.cc_user_ids?.length > 0
      for userId in params.cc_user_ids
        # Skip current user (shouldn't happen but safety check)
        continue if String(userId) == currentUserId
        
        # Fetch user data synchronously to populate initial options
        $.ajax(
          url: "#{App.Config.get('api_path')}/users/#{userId}"
          async: false
          success: (user) ->
            displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
            displayName = user.login if displayName == ''
            displayName += " (#{user.email})" if user.email
            
            attribute.options.push({
              value: user.id
              name: displayName
            })
        )
    
    # Render searchable multi-select
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Get select2 element for dynamic search
    select2Element = element.find('select')
    
    # Track loaded user IDs to avoid duplicates
    loadedUserIds = params.cc_user_ids?.map((id) -> String(id)) || []
    
    # Hook into select2 search
    searchTimer = null
    element.on 'input', '.select2-search__field, .js-input', (e) ->
      query = $(e.target).val()?.trim()
      
      clearTimeout(searchTimer) if searchTimer
      
      # Need at least 2 characters
      return if !query || query.length < 2
      
      searchTimer = setTimeout(->
        # Fetch from backend
        $.ajax(
          url: "#{App.Config.get('api_path')}/tickets/cc_users"
          data:
            query: query
          success: (data) ->
            users = data.users || []
            
            # Add new users to dropdown (don't remove existing selected ones)
            for user in users
              # Skip current user (backend should already do this)
              continue if String(user.id) == currentUserId
              # Skip already loaded users
              continue if loadedUserIds.includes(String(user.id))
              
              displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
              displayName = user.login if displayName == ''
              displayName += " (#{user.email})" if user.email
              
              # Add to select2
              option = new Option(displayName, user.id, false, false)
              select2Element.append(option)
              loadedUserIds.push(String(user.id))
            
            # Trigger change to update select2 dropdown
            select2Element.trigger('change')
        )
      , 300)  # 300ms debounce
    
    element
