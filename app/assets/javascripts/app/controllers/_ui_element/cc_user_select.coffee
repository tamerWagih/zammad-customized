# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Use native searchable_select structure with custom relation filtering
    attribute.tag = 'searchable_select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.placeholder = __('Search for users...')
    attribute.filter = (users, type, params) ->
      # Filter to only show agents and customers, exclude current user
      current_user_id = App.User.current()?.id
      users.filter (user) ->
        return false if user.id is current_user_id
        return false if !user.active
        return user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
    
    # Use native searchable_select
    App.UiElement.searchable_select.render(attribute, params)

# This file now uses the native searchable_select component
# All the custom logic has been replaced with native Zammad functionality
