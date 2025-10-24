# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Search-only multi-select with proper name display
    # Load all users upfront, searchable_select handles search
    
    console.log "[CC_USERS] Rendering CC user select"
    currentUserId = App.Session.get('id')
    
    # Configure as searchable multi-select
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''
    attribute.placeholder = __('Type to search users...')
    attribute.options = []
    
    # Load users synchronously to ensure options are ready
    userOptions = []
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      async: false  # Synchronous to ensure options are loaded before rendering
      success: (data) ->
        users = if data.users then data.users else data
        console.log "[CC_USERS] Loaded #{users?.length || 0} users from API"
        
        for user in users
          continue if user.id == currentUserId
          
          # Build display name
          displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          displayName = user.login if displayName == ''
          displayName = user.email if !displayName
          
          # Add user type and email
          userType = if user.user_type == 'agent' then 'Agent' else 'Customer'
          if user.email
            displayName += " (#{user.email}) [#{userType}]"
          else
            displayName += " [#{userType}]"
          
          userOptions.push({
            value: user.id
            name: displayName
          })
        
        console.log "[CC_USERS] Built #{userOptions.length} user options"
      
      error: (xhr) ->
        console.error "[CC_USERS] Failed to load users:", xhr.status
    )
    
    # Set the options
    attribute.options = userOptions
    
    # Render with searchable_select
    element = App.UiElement.searchable_select.render(attribute, params)
    
    console.log "[CC_USERS] Rendered with #{userOptions.length} options"
    element
