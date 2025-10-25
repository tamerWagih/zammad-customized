# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    
    # Use Zammad's NATIVE user_autocompletion_search component
    # This automatically:
    # - Calls /tickets/cc_users (which filters out current user)
    # - Handles multi-select
    # - Shows names not IDs
    # - Handles backend search
    # - Works like owner/customer selection
    
    # Configure to use our custom CC endpoint
    attribute.disableCreateObject = true
    attribute.multiple = true
    attribute.minLenght = 2
    attribute.source = "#{App.Config.get('api_path')}/tickets/cc_users"
    
    # Use Zammad's native UserOrganizationAutocompletion
    new App.UserOrganizationAutocompletion(attribute: attribute, params: params).element()
