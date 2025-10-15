# coffeelint: disable=camel_case_classes
class App.UiElement.user_autocompletion_cc extends App.UiElement.ApplicationUiElement
  @render: (attributeConfig, params = {}, form) ->
    attribute = $.extend(true, {}, attributeConfig)

    # Get current values if any
    selectedUsers = []
    if params[attribute.name] || attribute.value
      userIds = params[attribute.name] || attribute.value
      userIds = [userIds] unless _.isArray(userIds)
      
      for userId in userIds
        if App.User.exists(userId)
          user = App.User.find(userId)
          selectedUsers.push
            id: user.id
            label: user.displayName()
            value: user.email || user.login
    
    # Create custom SearchableAjaxSelect for CC users
    searchableAjaxSelectObject = new App.CCUserSelect(
      delegate: form
      attribute:
        value: selectedUsers
        name: attribute.name
        placeholder: App.i18n.translateInline('Search agents and customers...')
        limit: 40
        relation: 'User'
        ajax: true
        multiple: true
    )
    
    searchableAjaxSelectObject.element()

# Custom CC User Select component
class App.CCUserSelect extends App.SearchableAjaxSelect
  
  # Override searchUrl to add permissions filter
  searchUrl: ->
    "#{App.Config.get('api_path')}/users/search"
  
  # Override searchQuery to add backend filtering for agents and customers only
  searchQuery: (query) ->
    currentUserId = App.Session.get('id')
    
    # Backend filtering: only users with ticket.agent OR ticket.customer permission
    # This is MUCH more efficient than loading all users and filtering on frontend
    {
      query: query || '*'
      limit: @attribute.limit || 40
      permissions: ['ticket.agent', 'ticket.customer']  # Backend filters by permissions
      full: false  # We don't need full user data
      term: query  # For label-based response format
    }
  
  # Override filterResults to exclude current user (frontend filter)
  filterResults: (results) ->
    currentUserId = App.Session.get('id')
    
    # Backend already filtered by permissions
    # We just need to exclude current user
    filtered = results.filter (user) ->
      user.id.toString() != currentUserId.toString()
    
    filtered
  
  # Override formatResults to ensure proper display
  formatResults: (results) ->
    formattedResults = []
    
    for item in results
      # Results from backend with 'term' parameter come as {id, label, value}
      if item.label?
        formattedResults.push
          id: item.id
          label: item.label
          value: item.value || item.label
          inactive: item.inactive || false
      else
        # Fallback for direct user objects
        user = item
        displayName = user.firstname || ''
        displayName += ' ' if user.firstname && user.lastname
        displayName += user.lastname || ''
        displayName = user.login if displayName.trim() == ''
        displayName = user.email if !displayName
        
        formattedResults.push
          id: user.id
          label: displayName
          value: user.email || displayName
          inactive: user.active == false
    
    formattedResults

