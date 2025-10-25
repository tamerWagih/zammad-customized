# coffeelint: disable=camel_case_classes

# Custom SearchableAjaxSelect for CC users
class App.CcUserAjaxSelect extends App.SearchableAjaxSelect
  
  constructor: ->
    super
    # Initialize search result cache (inherited from parent)
  
  # Override to use our custom CC users endpoint
  ajaxAttributes: =>
    query = @input.val()
    cacheKey = @cacheKey()
    
    console.log "[CC_AJAX] Searching users with query: '#{query}'"
    
    {
      id:   @options.attribute.id
      type: 'GET'
      url:  "#{App.Config.get('api_path')}/tickets/cc_users"
      data: 
        search: query
        per_page: @options.attribute.limit || 50
      processData: true
      success: (data, status, xhr) =>
        console.log "[CC_AJAX] Received #{data.users?.length || 0} users"
        # Cache search result
        @searchResultCache[cacheKey] = data
        @renderResponse(data, query)
      error: =>
        console.error "[CC_AJAX] Failed to load users"
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
    
    # Convert users to options format {name, value}
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
    
    # Update options using parent's renderOptions method
    @optionsList.html @renderOptions(options)
    
    # Refresh elements (CRITICAL - updates internal state)
    @refreshElements()

