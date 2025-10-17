# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_autocompletion
  @render: (attribute, params = {}) ->
    # Find Agent and Customer role IDs (same pattern as approver selection)
    agentRole = App.Role.findByAttribute('name', 'Agent')
    customerRole = App.Role.findByAttribute('name', 'Customer')
    
    if !agentRole && !customerRole
      console.error "[CC_FILTER] Neither Agent nor Customer role found"
      return new App.UserOrganizationAutocompletion(attribute: attribute, params: params).element()
    
    # Create modified attribute with backend filtering (same pattern as approver)
    ccAttribute = $.extend(true, {}, attribute)
    
    # Override the ajax method to add role filtering to API call
    originalAjax = App.UserOrganizationAutocompletion.prototype.ajax
    App.UserOrganizationAutocompletion.prototype.ajax = (options) ->
      # Only modify CC-related calls
      if @attribute?.tag == 'cc_user_autocompletion'
        console.log "[CC_FILTER] Modifying API call for CC filtering"
        
        # Add role filtering to the API call (same as approver selection)
        if options.data
          options.data.role_ids = []
          options.data.role_ids.push(agentRole.id) if agentRole
          options.data.role_ids.push(customerRole.id) if customerRole
          console.log "[CC_FILTER] Added role_ids to API call: #{JSON.stringify(options.data.role_ids)}"
        
        # Override success callback to filter results (same pattern as approver)
        originalSuccess = options.success
        options.success = (data, status, xhr) =>
          console.log "[CC_FILTER] API response received, filtering users"
          
          # Process the response data (same as approver selection)
          users = if Array.isArray(data) then data else (data?.users || [])
          current_user_id = App.User.current()?.id
          
          # Filter users (same logic as approver selection)
          filteredUsers = users.filter (user) ->
            return false if user.id is current_user_id  # Exclude current user
            return false if user.active is false        # Exclude inactive users
            return false if !user.email                 # Exclude users without email
            true
          
          console.log "[CC_FILTER] Filtered #{users.length} users down to #{filteredUsers.length}"
          
          # Modify the response to only include filtered users
          if Array.isArray(data)
            # Replace the array with filtered users
            filteredData = filteredUsers
          else if data?.users
            # Replace the users array
            data.users = filteredUsers
            filteredData = data
          else
            filteredData = data
          
          # Call original success with filtered data
          originalSuccess(filteredData, status, xhr)
      
      # Call original ajax method
      originalAjax.call(this, options)
    
    # Create the autocompletion instance
    autocompletion = new App.UserOrganizationAutocompletion(attribute: ccAttribute, params: params)
    
    # Restore original ajax method after creating instance
    App.UserOrganizationAutocompletion.prototype.ajax = originalAjax
    
    autocompletion.element()
