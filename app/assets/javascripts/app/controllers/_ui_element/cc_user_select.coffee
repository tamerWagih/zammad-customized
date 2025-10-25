# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    
    # Get current user ID for filtering
    currentUserId = String(App.Session.get('id'))
    
    # Configure searchable_select (proven to work)
    # CRITICAL: Do NOT set attribute.relation = 'User' - it bypasses our filtering!
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Type to search users (min 2 chars)...')
    attribute.options = []  # Start empty
    
    # Render standard searchable_select
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Manual AJAX search on the rendered element
    select2 = element.find('select')
    searchTimer = null
    
    # Hook into select2 search
    element.on 'select2:opening', ->
      # Message to type
      console.log 'CC: Opening - user must type to search'
    
    element.on 'input', '.select2-search__field', (e) ->
      query = $(e.target).val()?.trim()
      
      clearTimeout(searchTimer) if searchTimer
      return if !query || query.length < 2
      
      searchTimer = setTimeout(->
        $.ajax(
          url: "#{App.Config.get('api_path')}/tickets/cc_users"
          data:
            term: query  # Use 'term' like native Zammad search
          success: (data) ->
            # Data is in Zammad's label/value format from model_search_render
            select2.empty()
            
            for item in data
              # Skip current user (double-check, backend should already filter)
              continue if String(item.id) == currentUserId
              
              # Add to select2
              option = new Option(item.label, item.id, false, false)
              $(option).data('inactive', item.inactive) if item.inactive
              select2.append(option)
            
            select2.trigger('change')
        )
      , 300)
    
    element
