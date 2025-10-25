# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    
    # Use Zammad's native user_autocompletion_search pattern
    # This handles:
    # - Backend /users/search API
    # - Multi-select
    # - Shows names not IDs
    # - Handles search automatically
    
    attribute.disableCreateObject = true
    attribute.multiple = true
    attribute.minLenght = 2
    
    # Use Zammad's native UserOrganizationAutocompletion
    # But we need to exclude current user, so we'll use a custom filter
    currentUserId = App.Session.get('id')
    
    # Add a filter to exclude current user from results
    originalCallback = attribute.callback
    attribute.callback = (params_arg) ->
      # Filter out current user from cc_user_ids
      if params_arg?.cc_user_ids
        params_arg.cc_user_ids = params_arg.cc_user_ids.filter (id) -> 
          String(id) != String(currentUserId)
      
      # Call original callback if exists
      originalCallback?(params_arg)
    
    # Use native component
    new App.UserOrganizationAutocompletion(attribute: attribute, params: params).element()
