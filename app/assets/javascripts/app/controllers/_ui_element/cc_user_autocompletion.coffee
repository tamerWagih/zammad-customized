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
              console.log "[CC_FILTER] Processing API response", data
              
              # Check if data has the expected structure
              if !data || typeof data != 'object'
                console.log "[CC_FILTER] Invalid data structure, passing through"
                return originalSuccess(data, status, xhr)
              
              # Get current user ID
              current_user_id = App.User.current()?.id
              
              # Filter data.result array (expected format: [{type: 'User', id: X}, ...])
              if data.result && Array.isArray(data.result)
                console.log "[CC_FILTER] Filtering result array with #{data.result.length} items"
                
                # Filter the result array
                filteredResult = data.result.filter (item) ->
                  # Only filter User items, leave Organizations as-is
                  if item.type == 'User'
                    # Get the full user object from assets
                    user = data.assets?.User?[item.id]
                    return false if !user
                    return false if user.id is current_user_id
                    return false if user.active is false
                    return false if !user.email
                    true
                  else
                    # Keep non-User items (like Organizations)
                    true
                
                console.log "[CC_FILTER] Filtered #{data.result.length} items to #{filteredResult.length}"
                data.result = filteredResult
              else
                console.log "[CC_FILTER] No result array found, passing through unchanged"
              
              # Call original success callback with filtered data
              originalSuccess(data, status, xhr)
        
        # Call parent ajax method
        super(options)
    
    # Create instance with custom class
    autocompletion = new CcUserAutocompletion(attribute: attribute, params: params)
    autocompletion.element()
