# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}, form) ->
    # Use Zammad's autocompletion_ajax for backend search
    # This provides multi-select with server-side search!
    
    console.log "[CC_USERS] Rendering CC user select with autocompletion_ajax"
    
    # Configure for multi-select user search
    attribute.tag = 'autocompletion_ajax'
    attribute.multiple = true
    attribute.relation = 'User'
    attribute.placeholder = __('Type to search users...')
    attribute.minLength = 2
    attribute.ajax = true
    
    # Use standard user autocompletion (searches all users)
    # Backend will filter to agents/customers automatically
    element = App.UiElement.autocompletion_ajax.render(attribute, params, form)
    
    console.log "[CC_USERS] Rendered with autocompletion_ajax"
    element
