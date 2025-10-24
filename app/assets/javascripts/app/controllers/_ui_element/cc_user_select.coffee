# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Simple clean approach: Load users from API FIRST, then render searchable_select
    # This is the proper way - searchable_select expects options when rendered
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.placeholder = __('Loading users...')
    attribute.relation = ''
    
    console.log "[CC_USERS] Starting CC dropdown render"
    
    # Load users synchronously so we can populate options before rendering
    options = @loadUsersSync()
    
    if options && Object.keys(options).length > 0
      # Users loaded successfully - render with options
      attribute.options = options
      attribute.placeholder = __('Select users to CC...')
      console.log "[CC_USERS] Rendering with #{Object.keys(options).length} users"
    else
      # Failed to load or no users - render empty with helpful message
      attribute.options = {}
      attribute.placeholder = __('No users available for CC')
      console.log "[CC_USERS] No users loaded, rendering empty dropdown"
    
    # Render the searchable select with options already populated
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Add validation to prevent selecting current user
    currentUserId = App.Session.get('id')?.toString()
    element.find('select').on 'change', ->
      selectedValues = $(this).val() || []
      
      # Filter out current user if somehow selected
      if currentUserId && selectedValues.includes(currentUserId)
        console.error "[CC_USERS] ❌ Current user #{currentUserId} was selected! Removing..."
        filteredValues = selectedValues.filter (id) -> id != currentUserId
        $(this).val(filteredValues).trigger('change')
    
    console.log "[CC_USERS] CC dropdown rendered successfully"
    element

  # Load users synchronously from API
  @loadUsersSync: ->
    console.log "[CC_USERS] Loading users synchronously from API"
    
    options = {}
    currentUserId = App.Session.get('id')
    
    # Make synchronous AJAX request to load users
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      async: false  # CRITICAL: Synchronous so we can return options immediately
      success: (data) ->
        users = if data.users then data.users else data
        console.log "[CC_USERS] Loaded #{users?.length || 0} users from API"
        
        if users && users.length > 0
          for user in users
            # Skip current user
            if user.id == currentUserId
              console.log "[CC_USERS] Skipping current user #{currentUserId}"
              continue
            
            # Build display name
            display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
            display_name = user.login if display_name == ''
            display_name = user.email if !display_name
            display_name = "User ##{user.id}" if !display_name
            
            # Add user type indicator
            user_type_label = switch user.user_type
              when 'agent' then '[Agent]'
              when 'customer' then '[Customer]'
              else '[User]'
            
            if user.email && display_name != user.email
              display_name += " (#{user.email})"
            display_name += " #{user_type_label}"
            
            # Store with STRING key (important for searchable_select)
            options[user.id.toString()] = display_name
          
          console.log "[CC_USERS] Built #{Object.keys(options).length} options"
          console.log "[CC_USERS] User IDs: #{Object.keys(options).slice(0, 5).join(', ')}..."
        else
          console.log "[CC_USERS] No users returned from API"
      
      error: (xhr) ->
        console.error "[CC_USERS] Failed to load users:", xhr.status, xhr.responseText
        options = {}
    )
    
    return options
