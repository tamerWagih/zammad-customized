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
    
    # Override the searchObject method to filter data before processing
    originalSearchObject = autocompletion.searchObject
    autocompletion.searchObject = (query) ->
      # Initialize role IDs before filtering
      @initializeRoleIds()
      
      # Call original search method
      originalSearchObject.call(this, query)
      
      # Filter results after they're loaded using a simple timeout
      setTimeout =>
        @filterResults()
      , 50
    
    # Simple and reliable filtering method
    autocompletion.filterResults = ->
      try
        elements = @recipientList.find('.js-object')
        console.log "[CC_FILTER] Found #{elements.length} elements to filter"
        
        elements.each (index, element) =>
          $element = $(element)
          userId = $element.data('id')
          
          if userId
            user = App.User.find(userId)
            
            if !user
              console.warn "[CC_FILTER] User not found for ID: #{userId}, removing"
              $element.remove()
              return
            
            # Check if user should be filtered out
            if !@isValidUserForCC(user)
              console.log "[CC_FILTER] Filtering out user: #{user.email} (not valid for CC)"
              $element.remove()
            else
              console.log "[CC_FILTER] Keeping user: #{user.email}"
      catch error
        console.error "[CC_FILTER] Error during filtering:", error
    
    # Check if user is valid for CC (Agent/Customer, not current user)
    autocompletion.isValidUserForCC = (user) ->
      return false if !user
      
      # Check if current user
      if user.id == @currentUserId
        return false
      
      # Check if user has Agent or Customer role
      return @isAgentOrCustomer(user)
    
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
    
    autocompletion.element()
