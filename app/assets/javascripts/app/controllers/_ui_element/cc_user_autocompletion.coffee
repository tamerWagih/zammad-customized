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
      roleIds
    
    # Create a custom class that extends UserOrganizationAutocompletion
    class CcUserAutocompletion extends App.UserOrganizationAutocompletion
      ajax: (options) ->
        # Only modify for CC field
        if @attribute?.tag == 'cc_user_autocompletion'
          # Get role IDs at runtime (when ajax is called, not at render time)
          roleIds = getRoleIds()
          
          # Add role filtering to the API call
          if options.data && roleIds.length > 0
            options.data.role_ids = roleIds
          
          # Wrap the original success callback to filter results
          if options.success
            originalSuccess = options.success
            options.success = (data, status, xhr) =>
              # Check if data has the expected structure
              if !data || typeof data != 'object'
                return originalSuccess(data, status, xhr)
              
              # Get current user ID
              current_user_id = App.User.current()?.id
              
              # /users/search returns: { record_ids: [...], assets: {...} }
              # Filter record_ids to exclude current user and inactive users
              if data.record_ids && Array.isArray(data.record_ids) && data.assets?.User
                filteredRecordIds = data.record_ids.filter (id) ->
                  user = data.assets.User[id]
                  return false if !user
                  return false if user.id is current_user_id
                  return false if user.active is false
                  return false if !user.email
                  true
                
                data.record_ids = filteredRecordIds
              
              # Global search returns: { result: [{type: 'User', id: X}, ...], assets: {...} }
              # Filter result array (for compatibility with global search)
              if data.result && Array.isArray(data.result) && data.assets?.User
                filteredResult = data.result.filter (item) ->
                  # Only filter User items, leave Organizations as-is
                  if item.type == 'User'
                    user = data.assets.User[item.id]
                    return false if !user
                    return false if user.id is current_user_id
                    return false if user.active is false
                    return false if !user.email
                    true
                  else
                    # Keep non-User items (like Organizations)
                    true
                
                data.result = filteredResult
              
              # Call original success callback with filtered data
              originalSuccess(data, status, xhr)
        
        # Call parent ajax method
        super(options)
    
    # Create instance with custom class
    autocompletion = new CcUserAutocompletion(attribute: attribute, params: params)
    autocompletion.element()
