# coffeelint: disable=camel_case_classes

# Custom SearchableAjaxSelect for CC users
class App.CcUserAjaxSelect extends App.SearchableAjaxSelect
  
  constructor: ->
    super
    # Initialize search result cache (inherited from parent)
  
  # Override render to prevent parent from using App.User model for initial options
  render: ->
    # Don't let parent load from App.User model - we use custom endpoint only
    # Skip the parent's render logic that checks @attribute.relation
    @renderElement()
  
  # Override objectString to prevent parent from using relation for URL construction
  objectString: =>
    'cc_users'
  
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
  
  # Override createToken to handle token creation with proper names
  createToken: ({name, value}) =>
    # Always use the name parameter (not value) for display
    # This ensures tokens show user names, not IDs
    content = {
      name: String(name)
      value: value
    }
    @input.before App.view('generic/token')(content)
  
  # Override to handle our custom response format
  renderResponse: (data, originalQuery) =>
    @hideLoader()
    
    users = if data.users then data.users else data
    return if !users
    
    # Convert users to options format {name, value}
    options = []
    
    for user in users
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

