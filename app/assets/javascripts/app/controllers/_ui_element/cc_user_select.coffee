# coffeelint: disable=camel_case_classes

class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # AJAX SELECT APPROACH: Server-side search for unlimited users
    # Uses SearchableAjaxSelect (extends SearchableSelect) to load users on-demand
    # - Initial load: Shows first 50 users or pre-selected users
    # - Search: Loads matching users from server dynamically
    # - Multi-select: Supports multiple CC users
    # - Caching: Same search queries use cached results
    
    # Configure attribute for SearchableAjaxSelect
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''  # Empty - we use custom endpoint and handle tokens ourselves
    attribute.ajax = true  # Enable AJAX search mode
    attribute.placeholder = __('Type to search users...')
    attribute.limit = 50  # Max results per search request
    
    # For existing CCs, pre-load their data for token display
    selectedIds = params.cc_user_ids || []
    if selectedIds.length > 0
      attribute.existingTokens = ''
      attribute.value = []
      
      # Load selected users to get their names (include current user if CC'd)
      App.Ajax.request(
        type: 'GET'
        url: "#{App.Config.get('api_path')}/tickets/cc_users?per_page=200"
        async: false  # Need names before rendering
        success: (data) ->
          users = if data.users then data.users else data
          users = users || []
          
          for userId in selectedIds
            userIdStr = userId.toString()
            
            # Find user in loaded data or existing assets
            user = users.find((u) -> u.id.toString() == userIdStr)
            if !user && App.User?.exists?(userIdStr)
              user = App.User.find(userIdStr)
            
            # Build a display name even if user is not in the preloaded list
            display_name = ''
            if user
              display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
              display_name = user.login if display_name == ''
              display_name = user.email if !display_name
              display_name += " (#{user.email})" if user?.email
            else
              display_name = "#{__('User')} ##{userIdStr}"
            
            attribute.value.push(userIdStr)
            attribute.existingTokens += App.view('generic/token')({
              name: display_name
              value: userIdStr
            })
      )
    
    # Create custom SearchableAjaxSelect for CC users
    new App.CcUserAjaxSelect(attribute: attribute, params: params).element()
