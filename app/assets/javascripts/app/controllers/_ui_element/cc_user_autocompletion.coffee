# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_autocompletion
  @render: (attribute, params = {}) ->
    # Use standard user autocompletion but with CC filtering
    autocompletion = new App.UserOrganizationAutocompletion(attribute: attribute, params: params)
    
    # Override the searchObject method to filter results after loading
    originalSearchObject = autocompletion.searchObject
    autocompletion.searchObject = (query) ->
      # Call original search method
      originalSearchObject.call(this, query)
      
      # Filter results after they're loaded
      setTimeout =>
        @filterResults()
      , 100
    
    # Add filtering method to remove non-Agent/Customer users
    autocompletion.filterResults = ->
      @recipientList.find('.js-object').each (index, element) =>
        $element = $(element)
        userId = $element.data('id')
        
        if userId
          user = App.User.find(userId)
          if !@isAgentOrCustomer(user)
            $element.remove()
    
    # Add filtering method
    autocompletion.isAgentOrCustomer = (user) ->
      return false if !user || !user.role_ids
      
      # Get Agent and Customer role IDs
      agentRoleId = @getRoleId('Agent')
      customerRoleId = @getRoleId('Customer')
      
      # Check if user has Agent or Customer role
      for roleId in user.role_ids
        if roleId == agentRoleId || roleId == customerRoleId
          return true
      
      return false
    
    # Add helper method to get role ID by name
    autocompletion.getRoleId = (roleName) ->
      for id, role of App.Role.all()
        if role && role.name == roleName
          return role.id
      return null
    
    autocompletion.element()
