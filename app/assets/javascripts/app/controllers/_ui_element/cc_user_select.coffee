# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # AJAX SELECT APPROACH: Server-side search for unlimited users
    # Uses SearchableAjaxSelect to load users on-demand via search
    # - Initial load: Empty or pre-selected users only
    # - Search: Loads matching users from server dynamically
    # - Multi-select: Supports multiple CC users
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.relation = ''  # Empty - we provide custom search
    attribute.placeholder = __('Type to search users...')
    attribute.limit = 50  # Max results per search
    
    # For existing CCs, pre-load their data for token display
    selectedIds = params.cc_user_ids || []
    if selectedIds.length > 0
      attribute.existingTokens = ''
      attribute.value = []
      
      # Load selected users to get their names
      currentUserId = App.Session.get('id')
      App.Ajax.request(
        type: 'GET'
        url: "#{App.Config.get('api_path')}/tickets/cc_users?per_page=200"
        async: false  # Need names before rendering
        success: (data) ->
          users = if data.users then data.users else data
          return if !users || users.length == 0
          
          for userId in selectedIds
            userIdStr = userId.toString()
            continue if userIdStr == currentUserId.toString()
            
            # Find user in loaded data
            user = users.find((u) -> u.id.toString() == userIdStr)
            if user
              display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
              display_name = user.login if display_name == ''
              display_name = user.email if !display_name
              display_name += " (#{user.email})" if user.email
              
              attribute.value.push(userIdStr)
              attribute.existingTokens += App.view('generic/token')({
                name: display_name
                value: userIdStr
              })
      )
    
    # Create custom SearchableAjaxSelect for CC users
    new App.CcUserAjaxSelect(attribute: attribute, params: params).element()

# Custom SearchableAjaxSelect for CC users
class App.CcUserAjaxSelect extends App.SearchableAjaxSelect
  
  # Override to use our custom CC users endpoint
  ajaxAttributes: =>
    query = @input.val()
    cacheKey = @cacheKey()
    
    {
      id:   @options.attribute.id
      type: 'GET'
      url:  "#{App.Config.get('api_path')}/tickets/cc_users"
      data: 
        search: query
        per_page: @options.attribute.limit || 50
      processData: true
      success: (data, status, xhr) =>
        # Cache search result
        @searchResultCache[cacheKey] = data
        @renderResponse(data, query)
      error: =>
        @hideLoader()
    }
  
  # Override cache key (no object string, just query)
  cacheKey: =>
    query = @input.val()
    "cc_users+#{query}"
  
  # Override to handle our custom response format
  renderResponse: (data, originalQuery) =>
    @hideLoader()
    
    users = if data.users then data.users else data
    return if !users
    
    # Convert users to options format
    currentUserId = App.Session.get('id')
    options = []
    
    for user in users
      continue if user.id == currentUserId
      
      display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
      display_name = user.login if display_name == ''
      display_name = user.email if !display_name
      display_name += " (#{user.email})" if user.email
      
      options.push({
        name: display_name
        value: user.id.toString()
      })
    
    # Update options
    @attribute.options = options
    
    # rebuild options list
    @optionsList.empty()
    @optionsList.html(@renderOptions(options))
    
    # Re-filter by current query (in case user kept typing)
    currentQuery = @input.val()
    if currentQuery isnt originalQuery
      @filterByQuery(currentQuery)
    else
      @filterByQuery(query: originalQuery, force: true)
  
  # Override to render options in correct format
  renderOptions: (options) ->
    html = ''
    for option in options
      html += "<div class='searchableSelect-option js-option' data-value='#{option.value}'>"
      html += "<span class='searchableSelect-option-text'>#{option.name}</span>"
      html += "</div>"
    html
