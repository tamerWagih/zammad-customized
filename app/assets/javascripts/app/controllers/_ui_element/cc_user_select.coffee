# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    
    # Get current user ID
    currentUserId = String(App.Session.get('id'))
    
    # Start with empty options - user MUST search
    attribute.options = []
    attribute.placeholder = __('Type to search users (min 2 chars)...')
    attribute.nulloption = false
    
    # Render searchable_select
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Get the actual select2 input
    select2Element = element.find('select')
    searchInput = element.find('.select2-search__field, .js-input')
    
    # Manual backend search on input
    searchTimer = null
    
    # Hook into select2's search event
    select2Element.on 'select2:opening', ->
      # Clear on open to force search
      select2Element.empty()
    
    # Listen to search input
    element.on 'input', '.select2-search__field, .js-input', (e) ->
      query = $(e.target).val()?.trim()
      
      clearTimeout(searchTimer) if searchTimer
      
      # Need at least 2 characters
      return if !query || query.length < 2
      
      searchTimer = setTimeout(->
        # Fetch from backend
        $.ajax(
          url: "#{App.Config.get('api_path')}/tickets/cc_users"
          data:
            query: query
          success: (data) ->
            users = data.users || []
            
            # Clear and rebuild options
            select2Element.empty()
            
            for user in users
              # Skip current user (backend should already do this)
              continue if String(user.id) == currentUserId
              
              displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
              displayName = user.login if displayName == ''
              displayName += " (#{user.email})" if user.email
              
              # Add option to select
              option = new Option(displayName, user.id, false, false)
              select2Element.append(option)
            
            # Trigger change to update select2 dropdown
            select2Element.trigger('change')
        )
      , 300)  # 300ms debounce
    
    element
