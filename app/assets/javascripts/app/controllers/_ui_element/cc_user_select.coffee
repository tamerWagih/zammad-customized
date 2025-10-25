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
    
    # Load users from backend API
    options = {}
    currentUserId = App.Session.get('id')
    
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      data:
        per_page: 1000  # Load up to 1000 users
      async: false
      success: (data) ->
        users = if data.users then data.users else data
        
        if users && users.length > 0
          for user in users
            # Skip current user (backend should already exclude, but safety check)
            continue if user.id == currentUserId
            
            # Build display name
            display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
            display_name = user.login if display_name == ''
            display_name = user.email if !display_name
            
            # Add user type and email
            user_type = if user.user_type == 'agent' then 'Agent' else 'Customer'
            if user.email
              display_name += " (#{user.email}) [#{user_type}]"
            else
              display_name += " [#{user_type}]"
            
            # Store as string key (required by searchable_select)
            options[user.id.toString()] = display_name
    )
    
    # Set options and render
    attribute.options = if Object.keys(options).length > 0 then options else {}
    attribute.placeholder = if Object.keys(options).length > 0 then __('Select users to CC...') else __('No users available')
    
    # Render searchable_select with all options
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # FIX: If params has existing cc_user_ids, ensure they display as names not IDs
    if params.cc_user_ids && params.cc_user_ids.length > 0
      selectElement = element.find('select')
      if selectElement.length > 0
        stringValues = params.cc_user_ids.map((id) -> id.toString())
        selectElement.val(stringValues)
        selectElement.trigger('change')
    
    element
