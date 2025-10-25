# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    
    # Get current user ID
    currentUserId = String(App.Session.get('id'))
    
    # Fetch initial users from backend (already excludes current user)
    userOptions = []
    
    $.ajax(
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      data:
        term: 'a'  # Get users starting with 'a' (or any letter) for initial load
        per_page: 100
      async: false
      success: (data) ->
        if data && Array.isArray(data)
          userOptions = data.map (item) ->
            # Backend already excludes current user, but double-check
            return null if String(item.id) == currentUserId
            
            {
              value: item.id
              name: item.label
            }
          userOptions = userOptions.filter (opt) -> opt != null
    )
    
    # Configure for searchable_select
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Type to search users...')
    attribute.options = userOptions
    # CRITICAL: Do NOT set attribute.relation = 'User' !!!
    # This bypasses our filtered options and loads all users from cache
    
    # Render searchable_select
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Add dynamic search
    searchTimer = null
    element.on 'input', '.select2-search__field', (e) ->
      query = $(e.target).val()?.trim()
      return if !query || query.length < 2
      
      clearTimeout(searchTimer) if searchTimer
      searchTimer = setTimeout(->
        $.ajax(
          url: "#{App.Config.get('api_path')}/tickets/cc_users"
          data:
            term: query
          success: (data) ->
            if data && Array.isArray(data)
              select2 = element.find('select')
              
              # Get currently selected IDs to preserve them
              selectedIds = select2.val() || []
              
              # Rebuild options
              select2.empty()
              
              for item in data
                continue if String(item.id) == currentUserId
                
                isSelected = selectedIds.includes(String(item.id))
                option = new Option(item.label, item.id, false, isSelected)
                select2.append(option)
              
              select2.trigger('change')
      , 300)
    
    element
