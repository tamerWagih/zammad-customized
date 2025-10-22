# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Load ALL users from backend API (not from cache)
    # This ensures consistent user list regardless of who's logged in
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.placeholder = __('Search for users to CC...')
    attribute.relation = 'User'
    attribute.options = {}
    
    # Load users from backend API synchronously
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      async: false  # Synchronous to ensure users load before rendering
      success: (data) =>
        # data is array of user objects
        for user in data
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          if user.email && display_name != user.email
            display_name += " (#{user.email})"
          
          attribute.options[user.id] = display_name
      error: (xhr) =>
        console.error 'Failed to load CC users:', xhr
        attribute.options = {}
    )
    
    # Render the searchable select with loaded options
    App.UiElement.searchable_select.render(attribute, params)
