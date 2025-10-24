# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Search-only multi-select with proper name display
    # Async loading for better performance
    
    console.log "[CC_USERS] Rendering CC user select"
    currentUserId = App.Session.get('id')
    
    # Configure as searchable multi-select
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''
    attribute.placeholder = __('Loading users...')
    attribute.options = []
    
    # Render immediately (empty state)
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Load users asynchronously (non-blocking)
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      async: true  # Non-blocking!
      success: (data) ->
        users = if data.users then data.users else data
        console.log "[CC_USERS] Loaded #{users?.length || 0} users from API"
        
        # Build options
        userOptions = []
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
        
        # Update the dropdown with loaded options
        selectElement = element.find('select')
        return if !selectElement.length
        
        # Populate options
        selectElement.empty()
        for option in userOptions
          optionEl = $('<option></option>')
            .attr('value', option.value)
            .text(option.name)
          selectElement.append(optionEl)
        
        # Restore selection if params has cc_user_ids
        if params.cc_user_ids?.length > 0
          selectedIds = params.cc_user_ids.map((id) -> id.toString())
          selectElement.val(selectedIds)
          console.log "[CC_USERS] Restored selection:", selectedIds
        
        # Update placeholder
        element.find('.form-control').attr('placeholder', __('Type to search users...'))
        
        # Trigger change to update UI
        selectElement.trigger('change')
        console.log "[CC_USERS] Dropdown populated successfully"
      
      error: (xhr) ->
        console.error "[CC_USERS] Failed to load users:", xhr.status
        element.find('.form-control').attr('placeholder', __('Failed to load users'))
    )
    
    element
