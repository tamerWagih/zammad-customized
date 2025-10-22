# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Load users from backend API asynchronously with proper error handling
    # This ensures consistent user list regardless of who's logged in
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.placeholder = __('Search for users to CC...')
    attribute.relation = 'User'
    attribute.options = {}
    
    # Show loading state initially
    loadingPlaceholder = __('Loading users...')
    attribute.placeholder = loadingPlaceholder
    
    # Render the searchable select first (with loading state)
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Load users from backend API asynchronously
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      async: true  # ✅ Non-blocking - doesn't freeze UI
      success: (data) =>
        # Handle both old format (array) and new format (object with users array)
        users = if data.users then data.users else data
        
        options = {}
        for user in users
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          if user.email && display_name != user.email
            display_name += " (#{user.email})"
          
          options[user.id] = display_name
        
        # Update the select with loaded options
        attribute.options = options
        attribute.placeholder = __('Search for users to CC...')
        
        # Re-render the select with the new options
        if element && element.length > 0
          # Find the select element and update it
          selectElement = element.find('select')
          if selectElement.length > 0
            # Clear existing options
            selectElement.empty()
            
            # Add null option
            selectElement.append($('<option value="">' + __('-') + '</option>'))
            
            # Add user options
            for id, name of options
              selectElement.append($('<option value="' + id + '">' + name + '</option>'))
            
            # Trigger change event to update any dependent UI
            selectElement.trigger('change')
        
        console.log "CC Users loaded successfully: #{Object.keys(options).length} users"
        
      error: (xhr) =>
        console.error 'Failed to load CC users:', xhr
        
        # Show error state to user
        attribute.placeholder = __('Error loading users - please refresh')
        attribute.options = {}
        
        # Update the select to show error state
        if element && element.length > 0
          selectElement = element.find('select')
          if selectElement.length > 0
            selectElement.empty()
            selectElement.append($('<option value="">' + __('Error loading users') + '</option>'))
        
        # Show user-friendly error message
        App.Notice.error(__('Failed to load CC users. Please refresh the page and try again.'))
    )
    
    # Return the element (initially with loading state)
    element
