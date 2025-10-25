# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # SOLUTION: Pre-render tokens with names using existingTokens pattern
    # 1. Load ALL agents/customers from backend API
    # 2. Build options for dropdown
    # 3. Pre-render tokens for selected users (shows names, not IDs!)
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''  # Empty - we provide explicit options
    attribute.placeholder = __('Loading users...')
    
    # Load users synchronously from our dedicated endpoint
    options = {}
    users_by_id = {}  # Store user data for token rendering
    currentUserId = App.Session.get('id')
    
    App.Ajax.request(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users?per_page=200"
      async: false  # Synchronous to get initial users before rendering
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
            userId = user.id.toString()
            options[userId] = display_name
            users_by_id[userId] = display_name  # Store for token lookup
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
    
    # CRITICAL: Pre-render tokens for selected users (prevents IDs from showing)
    selectedIds = params.cc_user_ids || []
    if selectedIds.length > 0
      attribute.existingTokens = ''
      for userId in selectedIds
        userIdStr = userId.toString()
        # Look up name from our loaded users
        userName = users_by_id[userIdStr]
        if userName
          # Pre-render token with name (not ID!)
          attribute.existingTokens += App.view('generic/token')({
            name: userName   # "Admin Amr (admin-amr@local.com)"
            value: userIdStr # "346"
          })
    
    # Render searchable_select with all options AND pre-rendered tokens
    # Note: SearchableSelect has built-in client-side filtering (types to filter the 200 users)
    element = App.UiElement.searchable_select.render(attribute, params)
    
    element
