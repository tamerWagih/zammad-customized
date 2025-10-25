# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Hybrid approach from commit 0c9c4aa6c7 (fixed IDs issue)
    # Load users async, properly handle selected values
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''  # CRITICAL: Empty, NOT 'User'!
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
        
        # Build options array
        options = []
        for user in users
          continue if user.id == currentUserId
          
          # Build display name (NO ROLE)
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          
          # Add email only (no role)
          if user.email
            display_name += " (#{user.email})"
          
          options.push({
            value: user.id.toString()
            name: display_name
          })
        
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
    
    # Clear and rebuild options
    selectElement.empty()
    
    for option in options
      optionElement = $('<option></option>')
        .attr('value', option.value)
        .text(option.name)
      selectElement.append(optionElement)
    
    # Set selection from params (fixes IDs issue - shows names not IDs)
    if selectedFromParams.length > 0
      valuesToSelect = selectedFromParams.map((id) -> id.toString())
      selectElement.val(valuesToSelect)
    
    # Update placeholder
    element.find('.form-control').attr('placeholder', __('Select users to CC...'))
    
    # Trigger change to update visual display (CRITICAL for showing names)
    selectElement.trigger('change')
