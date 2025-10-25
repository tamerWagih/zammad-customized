# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Hybrid approach from commit 0c9c4aa6c7 (fixed IDs issue)
    # Load users async, properly handle selected values
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''  # No relation - use our custom options
    attribute.placeholder = __('Loading users...')
    attribute.options = []  # Start empty
    
    currentUserId = App.Session.get('id')
    
    # Render first (empty state, non-blocking)
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Load users asynchronously
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users?per_page=1000"
      async: true  # Non-blocking
      success: (data) =>
        users = if data.users then data.users else data
        return if !users || users.length == 0
        
        # Build options array with 'selected' flag for pre-selected users
        options = []
        selectedIds = (params.cc_user_ids || []).map((id) -> id.toString())
        
        for user in users
          continue if user.id == currentUserId
          
          # Build display name (NO ROLE)
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          
          # Add email only (no role)
          if user.email
            display_name += " (#{user.email})"
          
          userId = user.id.toString()
          options.push({
            value: userId
            name: display_name
            selected: selectedIds.indexOf(userId) >= 0  # Mark if pre-selected
          })
        
        # Update attribute.options (this is what SearchableSelect uses internally!)
        attribute.options = options
        
        # Update the dropdown with loaded users
        @updateDropdown(element, options, params)
      
      error: (xhr) ->
        element.find('.form-control').attr('placeholder', __('Failed to load users'))
    )
    
    element
  
  @updateDropdown: (element, options, params) ->
    # Find the select element
    selectElement = element.find('select')
    return if !selectElement.length
    
    # Get selected values from params (for editing tickets with existing CCs)
    selectedFromParams = params.cc_user_ids || []
    
    # Clear and rebuild <select> options (for value/name mapping)
    selectElement.empty()
    
    for option in options
      optionElement = $('<option></option>')
        .attr('value', option.value)
        .text(option.name)
      selectElement.append(optionElement)
    
    # Set selection from params (for editing)
    if selectedFromParams.length > 0
      valuesToSelect = selectedFromParams.map((id) -> id.toString())
      selectElement.val(valuesToSelect)
    
    # Update placeholder
    element.find('.form-control').attr('placeholder', __('Select users to CC...'))
    
    # CRITICAL: Force searchable_select to rebuild its visual display
    # Find the SearchableSelect controller instance
    controller = element.data('controller')
    if controller
      # Update the options in the controller (THIS is what fixes IDs!)
      controller.attribute.options = options
      # Rebuild the select element display if method exists
      if controller.buildSelectList
        controller.buildSelectList()
      # Force UI update
      selectElement.trigger('change')
    else
      # Fallback: just trigger change
      selectElement.trigger('change')
