# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # PROPER APPROACH (like Approval Request Modal):
    # 1. Load ALL agents/customers from backend API
    # 2. Build options object
    # 3. Render searchable_select with options
    # 
    # DON'T use relation='User' - cache doesn't have all users!
    # (Only has users from current session activities)
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''  # Empty - we provide explicit options
    attribute.placeholder = __('Loading users...')
    
    # Load users synchronously from our dedicated endpoint
    options = {}
    currentUserId = App.Session.get('id')
    
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users?per_page=1000"
      async: false  # Synchronous to get all users before rendering
      success: (data) ->
        users = if data.users then data.users else data
        
        if users && users.length > 0
          for user in users
            # Skip current user (backend should already exclude, but safety check)
            continue if user.id == currentUserId
            
            # Build display name (NO ROLE)
            display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
            display_name = user.login if display_name == ''
            display_name = user.email if !display_name
            
            # Add email only (no role)
            if user.email
              display_name += " (#{user.email})"
            
            # Store as string key (required by searchable_select)
            options[user.id.toString()] = display_name
      error: (xhr) ->
        # Leave options empty
    )
    
    # Set options and render
    if Object.keys(options).length > 0
      attribute.options = options
      attribute.placeholder = __('Select users to CC...')
    else
      attribute.options = {}
      attribute.placeholder = __('No users available')
    
    # Render searchable_select with all options
    element = App.UiElement.searchable_select.render(attribute, params)
    
    element
