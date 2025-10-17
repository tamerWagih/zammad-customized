# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_autocompletion
  @render: (attribute, params = {}) ->
    # Use standard user autocompletion but with CC filtering
    autocompletion = new App.UserOrganizationAutocompletion(attribute: attribute, params: params)
    
    # Cache role IDs once to avoid repeated lookups
    autocompletion.agentRoleId = null
    autocompletion.customerRoleId = null
    autocompletion.currentUserId = App.User.current?.id
    
    # Initialize role IDs
    autocompletion.initializeRoleIds = ->
      if @agentRoleId == null || @customerRoleId == null
        @agentRoleId = @getRoleId('Agent')
        @customerRoleId = @getRoleId('Customer')
        console.log "[CC_FILTER] Role IDs cached - Agent: #{@agentRoleId}, Customer: #{@customerRoleId}"
    
    # Override the searchObject method to filter results after loading
    originalSearchObject = autocompletion.searchObject
    autocompletion.searchObject = (query) ->
      # Initialize role IDs before filtering
      @initializeRoleIds()
      
      # Call original search method
      originalSearchObject.call(this, query)
      
      # Use event-based filtering instead of setTimeout
      @setupEventBasedFiltering()
    
    # Setup event-based filtering to avoid race conditions
    autocompletion.setupEventBasedFiltering = ->
      # Remove any existing filter listeners to avoid duplicates
      @recipientList.off('DOMNodeInserted.cc_filter')
      
      # Use MutationObserver for reliable DOM change detection
      if @mutationObserver
        @mutationObserver.disconnect()
      
      @mutationObserver = new MutationObserver (mutations) =>
        @filterResults()
      
      # Start observing when recipientList is available
      if @recipientList && @recipientList.length > 0
        @mutationObserver.observe(@recipientList[0], {
          childList: true,
          subtree: true
        })
        console.log "[CC_FILTER] MutationObserver started"
      
      # Also filter immediately in case results are already loaded
      @filterResults()
    
    # Enhanced filtering method with error handling
    autocompletion.filterResults = ->
      try
        @recipientList.find('.js-object').each (index, element) =>
          $element = $(element)
          userId = $element.data('id')
          
          if userId
            user = App.User.find(userId)
            
            # Error handling for null user
            if !user
              console.warn "[CC_FILTER] User not found for ID: #{userId}, removing element"
              $element.remove()
              return
            
            # Check if user should be filtered out
            if !@isAgentOrCustomer(user)
              console.log "[CC_FILTER] Filtering out user: #{user.email} (not Agent/Customer)"
              $element.remove()
            else if @isCurrentUser(user)
              console.log "[CC_FILTER] Filtering out current user: #{user.email}"
              $element.remove()
            else
              console.log "[CC_FILTER] Keeping user: #{user.email}"
      catch error
        console.error "[CC_FILTER] Error during filtering:", error
    
    # Enhanced filtering method with cached role IDs
    autocompletion.isAgentOrCustomer = (user) ->
      return false if !user || !user.role_ids
      
      # Use cached role IDs
      @initializeRoleIds()
      
      # Check if user has Agent or Customer role
      for roleId in user.role_ids
        if roleId == @agentRoleId || roleId == @customerRoleId
          return true
      
      return false
    
    # Check if user is current user
    autocompletion.isCurrentUser = (user) ->
      return false if !user || !@currentUserId
      return user.id == @currentUserId
    
    # Enhanced helper method to get role ID by name with error handling
    autocompletion.getRoleId = (roleName) ->
      try
        roles = App.Role.all()
        if !roles
          console.warn "[CC_FILTER] App.Role.all() returned null/undefined"
          return null
        
        for id, role of roles
          if role && role.name == roleName
            return role.id
        
        console.warn "[CC_FILTER] Role '#{roleName}' not found"
        return null
      catch error
        console.error "[CC_FILTER] Error getting role ID for '#{roleName}':", error
        return null
    
    # Cleanup method to disconnect observers
    autocompletion.cleanup = ->
      if @mutationObserver
        @mutationObserver.disconnect()
        @mutationObserver = null
        console.log "[CC_FILTER] MutationObserver disconnected"
    
    # Override destroy method to cleanup
    originalDestroy = autocompletion.destroy
    autocompletion.destroy = ->
      @cleanup()
      originalDestroy?.call(this)
    
    autocompletion.element()
