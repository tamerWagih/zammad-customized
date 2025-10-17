# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_autocompletion
  @render: (attribute, params = {}) ->
    # Simple approach: Get users from memory like approval system does
    # This avoids API call complexity and potential errors
    
    current_user_id = App.User.current()?.id
    eligible_users = []
    
    # Get all agents and customers (same as approval pattern)
    for user_id, user of App.User.all()
      continue if !user.active  # Skip inactive users
      continue if !user.email   # Skip users without email
      continue if user.id is current_user_id  # Skip current user (can't CC yourself)
      
      # Include agents and customers
      if user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
        eligible_users.push(user)
    
    # Sort by display name (same as approval pattern)
    eligible_users = _.sortBy(eligible_users, (u) -> u.displayName())
    
    # Build options for multiselect
    options = []
    for user in eligible_users
      displayName = user.displayName()
      if user.email && displayName != user.email
        displayName = "#{displayName} <#{user.email}>"
      
      options.push
        value: user.id
        name: displayName
    
    # Use standard multiselect instead of autocomplete
    attribute_new = _.clone(attribute)
    attribute_new.options = options
    attribute_new.tag = 'multiselect'  # Use standard multiselect
    attribute_new.multiple = true
    attribute_new.nulloption = false
    
    App.UiElement.multiselect.render(attribute_new, params)
