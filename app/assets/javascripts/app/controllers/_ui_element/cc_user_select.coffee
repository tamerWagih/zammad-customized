# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Use searchable_select for search UI with custom CC endpoint
    # This endpoint is accessible by both agents and customers
    
    attribute.tag = 'searchable_select'
    attribute.relation = 'User'
    attribute.multiple = true
    attribute.nulloption = false
    attribute.placeholder = __('Search for users to CC...')
    
    # Don't use default relation loading
    delete attribute.relation
    
    # Start with empty options
    attribute.options = {}
    
    # Load users from custom CC endpoint (accessible by all authenticated users)
    $.ajax(
      type: 'GET'
      url: "#{App.Config.get('api_path')}/tickets/cc_users"
      processData: true
      success: (data) =>
        users = if Array.isArray(data) then data else (data?.users || [])
        
        # Build options
        attribute.options = {}
        for user in users
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          display_name = "User ##{user.id}" if !display_name
          
          # Add email in parentheses if different from display name
          if user.email && display_name != user.email
            display_name += " (#{user.email})"
          
          attribute.options[user.id] = display_name
        
        # Re-render with loaded users
        $element = $(element)
        new_element = App.UiElement.searchable_select.render(attribute, params)
        $element.replaceWith(new_element)
        
      error: (xhr, status, error) =>
        # Fallback: show all active users from App.User.all()
        all_users = App.User.all()
        current_user_id = App.User.current()?.id
        
        attribute.options = {}
        for user_id, user of all_users
          continue if user.id is current_user_id
          continue if !user.active
          
          display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
          display_name = user.login if display_name == ''
          display_name = user.email if !display_name
          
          attribute.options[user.id] = display_name
        
        # Re-render with fallback users
        $element = $(element)
        new_element = App.UiElement.searchable_select.render(attribute, params)
        $element.replaceWith(new_element)
    )
    
    # Render initial element
    element = App.UiElement.searchable_select.render(attribute, params)
    element

# CC user select component
# - Uses searchable_select for search UI and multiselect
# - Custom endpoint /tickets/cc_users accessible by all authenticated users
# - Shows all agents and customers (excluding current user)
# - Fallback to App.User.all() if endpoint fails
