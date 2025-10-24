# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Load users first, THEN render searchable_select
    # This ensures search functionality works properly
    
    console.log "[CC_USERS] Rendering CC user select"
    currentUserId = App.Session.get('id')
    
    # Build options from backend
    userOptions = []
    
    # Load users synchronously to ensure options are ready for searchable_select
    # Load ALL users (up to 10,000) so search finds everyone
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users?per_page=10000"
      async: false
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
    
    # Configure searchable multi-select with loaded options
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''
    attribute.placeholder = __('Type to search users...')
    attribute.options = userOptions  # Options loaded and ready!
    
    # Now render with all options available - search will work!
    element = App.UiElement.searchable_select.render(attribute, params)
    
    console.log "[CC_USERS] Rendered with #{userOptions.length} searchable options"
    element
