# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Server-side search as you type
    # Only loads users when searching - much more performant!
    
    console.log "[CC_USERS] Rendering CC user select with server-side search"
    currentUserId = App.Session.get('id')
    
    # Create container
    item = $('<div class="cc-user-select-container"></div>')
    
    # Selected users display
    selectedContainer = $('<div class="cc-selected-users"></div>')
    item.append(selectedContainer)
    
    # Search input
    searchInput = $('<input type="text" class="form-control cc-search-input" placeholder="Type to search users..." />')
    item.append(searchInput)
    
    # Dropdown for results
    dropdown = $('<div class="cc-dropdown"></div>')
    item.append(dropdown)
    
    # Hidden inputs for selected user IDs (Rails array format)
    hiddenContainer = $('<div class="cc-hidden-inputs"></div>')
    item.append(hiddenContainer)
    
    # Store selected users
    selectedUsers = []
    
    # Function to update hidden inputs
    updateHiddenInputs = ->
      hiddenContainer.empty()
      for user in selectedUsers
        # Rails expects: cc_user_ids[]
        hidden = $("<input type='hidden' name='cc_user_ids[]' value='#{user.id}' />")
        hiddenContainer.append(hidden)
      console.log "[CC_USERS] Selected #{selectedUsers.length} users"
    
    # Function to add selected user token
    addUserToken = (user) ->
      return if selectedUsers.find((u) -> u.id == user.id)
      
      selectedUsers.push(user)
      
      token = $("<div class='cc-token' data-id='#{user.id}'>
                   <span class='cc-token-name'>#{user.name}</span>
                   <span class='cc-token-remove'>×</span>
                 </div>")
      selectedContainer.append(token)
      
      updateHiddenInputs()
    
    # Restore from params
    if params.cc_user_ids?.length > 0
      for userId in params.cc_user_ids
        do (userId) ->
          $.ajax(
            type: 'GET'
            url: "#{App.Config.get('api_path')}/users/#{userId}"
            async: false
            success: (user) ->
              return if user.id == currentUserId
              
              displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
              displayName = user.login if displayName == ''
              
              addUserToken(
                id: user.id
                name: displayName
              )
          )
    
    # Search timer for debouncing
    searchTimer = null
    
    # Handle search input
    searchInput.on 'input', ->
      query = searchInput.val().trim()
      
      clearTimeout(searchTimer) if searchTimer
      
      if query.length < 2
        dropdown.hide().empty()
        return
      
      # Debounce 300ms
      searchTimer = setTimeout(->
        console.log "[CC_USERS] Searching: #{query}"
        
        $.ajax(
          type: 'GET'
          url: "#{App.Config.get('api_path')}/tickets/cc_users"
          data:
            search: query
            per_page: 50
          success: (data) ->
            users = if data.users then data.users else data
            console.log "[CC_USERS] Found #{users.length} users"
            
            dropdown.empty()
            
            if users.length == 0
              dropdown.html('<div class="cc-no-results">No users found</div>').show()
              return
            
            for user in users
              continue if user.id == currentUserId
              continue if selectedUsers.find((u) -> u.id == user.id)
              
              displayName = "#{user.firstname || ''} #{user.lastname || ''}".trim()
              displayName = user.login if displayName == ''
              
              userType = if user.user_type == 'agent' then 'Agent' else 'Customer'
              emailDisplay = if user.email then " (#{user.email})" else ""
              
              resultItem = $("<div class='cc-result' data-id='#{user.id}'>
                               <div class='cc-result-name'>#{displayName}#{emailDisplay}</div>
                               <div class='cc-result-type'>[#{userType}]</div>
                             </div>")
              resultItem.data('user', { id: user.id, name: displayName })
              dropdown.append(resultItem)
            
            dropdown.show()
          
          error: ->
            console.error "[CC_USERS] Search failed"
            dropdown.html('<div class="cc-error">Search failed</div>').show()
        )
      , 300)
    
    # Handle result click
    dropdown.on 'click', '.cc-result', (e) ->
      user = $(e.currentTarget).data('user')
      addUserToken(user)
      searchInput.val('').focus()
      dropdown.hide().empty()
    
    # Handle token removal
    selectedContainer.on 'click', '.cc-token-remove', (e) ->
      token = $(e.target).closest('.cc-token')
      userId = parseInt(token.data('id'))
      token.remove()
      selectedUsers = selectedUsers.filter((u) -> u.id != userId)
      updateHiddenInputs()
    
    # Hide dropdown when clicking outside
    $(document).on 'click', (e) ->
      if !$(e.target).closest('.cc-user-select-container').length
        dropdown.hide()
    
    # Focus input when container clicked
    searchInput.on 'focus', ->
      dropdown.show() if dropdown.children().length > 0
    
    console.log "[CC_USERS] Server-side search ready"
    item
