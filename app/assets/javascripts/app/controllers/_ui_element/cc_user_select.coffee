# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # OPTION 3: Hybrid approach - async loading with pagination
    # - Non-blocking UI (async: true)
    # - Load first 100 users
    # - Searchable out of the box
    # - Handles large user bases
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''  # No relation - we provide explicit options
    attribute.placeholder = __('Loading users...')
    attribute.options = []  # Start empty
    
    console.log "[CC_USERS] Starting async load of CC users"
    currentUserId = App.Session.get('id')
    
    # Render first (empty state, non-blocking)
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Load users asynchronously (non-blocking)
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users?per_page=100"
      async: true  # Non-blocking!
      success: (data) =>
        users = if data.users then data.users else data
        console.log "[CC_USERS] Loaded #{users?.length || 0} users"
        
        return if !users || users.length == 0
        
        # Build options array
        options = []
          for user in users
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
          
          options.push({
            value: user.id.toString()
            name: display_name
          })
        
        console.log "[CC_USERS] Built #{options.length} options"
        
        # Update the dropdown with loaded users
        @updateDropdown(element, options, params)
      
      error: (xhr) ->
        console.error "[CC_USERS] Failed to load users:", xhr.status
        element.find('.form-control').attr('placeholder', __('Failed to load users'))
    )
    
    console.log "[CC_USERS] Dropdown rendered (loading in background)"
    element
  
  @updateDropdown: (element, options, params) ->
    console.log "[CC_USERS] Updating dropdown with #{options.length} options"
    
    # Find the select element
    selectElement = element.find('select')
    return if !selectElement.length
    
    # Get currently selected values (if any)
    currentlySelected = selectElement.val() || []
    selectedFromParams = params.cc_user_ids || []
    
    console.log "[CC_USERS] Currently selected:", currentlySelected
    console.log "[CC_USERS] Selected from params:", selectedFromParams
    
    # Clear and rebuild options
        selectElement.empty()
    
    for option in options
      optionElement = $('<option></option>')
        .attr('value', option.value)
        .text(option.name)
      selectElement.append(optionElement)
    
    # Restore or set selection
    valuesToSelect = if currentlySelected.length > 0
                       currentlySelected
                     else if selectedFromParams.length > 0
                       selectedFromParams.map((id) -> id.toString())
                     else
                       []
    
    if valuesToSelect.length > 0
      selectElement.val(valuesToSelect)
      console.log "[CC_USERS] Set selected values:", valuesToSelect
    
    # Update placeholder
    element.find('.form-control').attr('placeholder', __('Select users to CC...'))
    
    # CRITICAL: Force searchable_select to rebuild its visual display
    # Find the searchable_select controller instance
    controller = element.data('controller')
    if controller
      console.log "[CC_USERS] Found searchable_select controller, rebuilding"
      # Update the options in the controller
      controller.attribute.options = options
      # Rebuild the select element display
      if controller.buildSelectList
        controller.buildSelectList()
      # Force UI update
      selectElement.trigger('change')
    else
      # Fallback: just trigger change
      selectElement.trigger('change')
      console.log "[CC_USERS] No controller found, triggered change event"
    
    console.log "[CC_USERS] Dropdown updated successfully"
