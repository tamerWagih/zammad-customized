# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_autocompletion
  @render: (attribute, params = {}) ->
    # Helper function to get role IDs (lazy loading)
    getRoleIds = ->
      roleIds = []
      agentRole = App.Role.findByAttribute('name', 'Agent')
      customerRole = App.Role.findByAttribute('name', 'Customer')
      roleIds.push(agentRole.id) if agentRole
      roleIds.push(customerRole.id) if customerRole
      console.log "[CC_FILTER] Found role IDs: #{JSON.stringify(roleIds)}"
      roleIds
    
    # Create a custom class that extends UserOrganizationAutocompletion
    class CcUserAutocompletion extends App.UserOrganizationAutocompletion
      ajax: (options) ->
        # Only modify for CC field
        if @attribute?.tag == 'cc_user_autocompletion'
          console.log "[CC_FILTER] Intercepting ajax call for CC field"
          
          # Get role IDs at runtime (when ajax is called, not at render time)
          roleIds = getRoleIds()
          
          # Add role filtering to the API call
          if options.data && roleIds.length > 0
            options.data.role_ids = roleIds
            console.log "[CC_FILTER] Added role_ids to API call"
          
          # Wrap the original success callback to filter results
          if options.success
            originalSuccess = options.success
            options.success = (data, status, xhr) =>
              console.log "[CC_FILTER] Processing API response"
              
              # Safely extract users array
              users = []
              if Array.isArray(data)
                users = data
              else if data && typeof data == 'object' && Array.isArray(data.assets?.User)
                users = data.assets.User
              else if data && typeof data == 'object' && data.result == 'ok'
                # For search results, don't filter here - already filtered by backend
                return originalSuccess(data, status, xhr)
              
              # Get current user ID
              current_user_id = App.User.current()?.id
              
              # Filter users
              if users.length > 0
                filteredUsers = users.filter (user) ->
                  return false if !user || typeof user != 'object'
                  return false if user.id is current_user_id
                  return false if user.active is false
                  return false if !user.email
                  true
                
                console.log "[CC_FILTER] Filtered #{users.length} users to #{filteredUsers.length}"
                
                # Update the data structure
                if Array.isArray(data)
                  data = filteredUsers
                else if data?.assets?.User
                  data.assets.User = filteredUsers
              
              # Call original success callback
              originalSuccess(data, status, xhr)
        
        # Call parent ajax method
        super(options)
    
    # Create instance with custom class
    autocompletion = new CcUserAutocompletion(attribute: attribute, params: params)
    autocompletion.element()
