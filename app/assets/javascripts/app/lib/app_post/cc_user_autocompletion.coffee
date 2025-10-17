# Custom CC User Autocompletion that filters to only Agents and Customers
class App.CcUserAutocompletion extends App.UserOrganizationAutocompletion
  
  # Override the buildObjectItem method to filter results
  buildObjectItem: (object) =>
    # Only show Agents and Customers
    if !@isAgentOrCustomer(object)
      return null
    
    # Call parent method
    super(object)
  
  # Check if user is Agent or Customer
  isAgentOrCustomer: (user) =>
    return false if !user || !user.role_ids
    
    # Get Agent and Customer role IDs
    agentRoleId = @getRoleId('Agent')
    customerRoleId = @getRoleId('Customer')
    
    # Check if user has Agent or Customer role
    for roleId in user.role_ids
      if roleId == agentRoleId || roleId == customerRoleId
        return true
    
    return false
  
  # Helper method to get role ID by name
  getRoleId: (roleName) =>
    for id, role of App.Role.all()
      if role && role.name == roleName
        return role.id
    return null
  
  # Override searchObject to filter results
  searchObject: (query) =>
    # Call parent searchObject
    super(query)
    
    # Filter the results after they're loaded
    @filterResults()
  
  # Filter the results to only show Agents and Customers
  filterResults: =>
    @recipientList.find('.js-object').each (index, element) =>
      $element = $(element)
      userId = $element.data('id')
      
      if userId
        user = App.User.find(userId)
        if !@isAgentOrCustomer(user)
          $element.remove()
