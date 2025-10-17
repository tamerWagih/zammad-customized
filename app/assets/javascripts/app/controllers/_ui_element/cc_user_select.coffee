# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Get Agent and Customer roles
    agentRole = App.Role.findByAttribute('name', 'Agent')
    customerRole = App.Role.findByAttribute('name', 'Customer')
    
    if !agentRole && !customerRole
      return $('<div class="alert alert-warning">Agent or Customer roles not found</div>')
    
    role_ids = [agentRole?.id, customerRole?.id].filter((id) -> id?)
    
    # Create container
    container = $('<div class="cc-user-select-container"></div>')
    
    # Add loading state
    container.html('<p class="loading">Loading users...</p>')
    
    # Make AJAX call exactly like approval system
    App.Ajax.request(
      id: 'users_for_cc'
      type: 'GET'
      url: "#{App.Config.get('api_path')}/users/search"
      data:
        role_ids: role_ids  # Backend filters by Agent + Customer roles
        limit: 1000
      processData: true
      success: (data, status, xhr) ->
        renderWithUsers(data, status, xhr, container, attribute, params)
      error: (xhr, status, error) ->
        container.html('<div class="alert alert-warning">Unable to load users. Please try again.</div>')
    )
    
    container

  renderWithUsers = (data, status, xhr, container, attribute, params) ->
    users = if Array.isArray(data) then data else (data?.users || [])
    
    # Backend already filtered by Agent + Customer roles
    # Just exclude current user and inactive users
    current_user_id = App.User.current()?.id
    eligible_users = users.filter (user) ->
      return false if user.id is current_user_id  # Exclude current user
      return false if user.active is false        # Exclude inactive users
      true
    
    # Sort users by name (firstname, lastname, or login)
    eligible_users.sort (a, b) ->
      # Get display name for sorting
      nameA = (a.firstname || '') + ' ' + (a.lastname || '')
      nameA = a.login if nameA.trim() == ''
      nameA = a.email if !nameA
      nameA = (nameA || '').toLowerCase()
      
      nameB = (b.firstname || '') + ' ' + (b.lastname || '')
      nameB = b.login if nameB.trim() == ''
      nameB = b.email if !nameB
      nameB = (nameB || '').toLowerCase()
      
      if nameA < nameB then -1 else if nameA > nameB then 1 else 0

    # Build select element exactly like approval system
    select = $('<select name="' + attribute.name + '" class="form-control" multiple size="8"></select>')
    
    # Add options
    for user in eligible_users
      name = "#{user.firstname || ''} #{user.lastname || ''}".trim() || user.login || user.email || "User ##{user.id}"
      displayName = name
      if user.email && name != user.email
        displayName = "#{name} (#{user.email})"
      
      option = $('<option value="' + user.id + '">' + displayName + '</option>')
      select.append(option)
    
    # Set selected values if any
    if params[attribute.name]
      selectedValues = if Array.isArray(params[attribute.name]) then params[attribute.name] else [params[attribute.name]]
      select.val(selectedValues)
    
    # Add help text
    helpText = $('<small class="help-block">Hold Ctrl/Cmd to select multiple users. Only agents and customers are shown.</small>')
    
    # Clear container and add elements
    container.empty()
    container.append(select)
    container.append(helpText)
    
    container
