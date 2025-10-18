# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    console.log('[CC_DEBUG] Rendering CC user select with attribute:', attribute)
    
    # Use native searchable_select structure with custom relation filtering
    attribute.tag = 'searchable_select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.placeholder = __('Search for users...')
    attribute.filter = (users, type, params) ->
      console.log('[CC_DEBUG] Filter called with users:', users.length)
      console.log('[CC_DEBUG] All users:', users)
      
      # Filter to only show agents and customers, exclude current user
      current_user_id = App.User.current()?.id
      console.log('[CC_DEBUG] Current user ID:', current_user_id)
      
      filtered_users = users.filter (user) ->
        console.log('[CC_DEBUG] Checking user:', user.login, 'ID:', user.id, 'Active:', user.active)
        console.log('[CC_DEBUG] User permissions:', user.permissions)
        console.log('[CC_DEBUG] Has ticket.agent:', user.permissions?('ticket.agent'))
        console.log('[CC_DEBUG] Has ticket.customer:', user.permissions?('ticket.customer'))
        
        return false if user.id is current_user_id
        return false if !user.active
        return user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
      
      console.log('[CC_DEBUG] Filtered users:', filtered_users.length)
      console.log('[CC_DEBUG] Filtered users list:', filtered_users)
      return filtered_users
    
    # Use native searchable_select
    App.UiElement.searchable_select.render(attribute, params)

# This file now uses the native searchable_select component
# All the custom logic has been replaced with native Zammad functionality
