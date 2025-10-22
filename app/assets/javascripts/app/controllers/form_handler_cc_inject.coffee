# Inject CC Users field into ticket creation form
class App.FormHandlerCcInject
  @run: (params, attribute, attributes, classname, form, ui) ->
    return if classname isnt 'create'  # Only on ticket creation
    return if attribute.name isnt 'group_id'  # Trigger after group_id renders
    
    # Check if already injected
    return if form.find('[name="cc_user_ids"]').length > 0
    
    # Find group_id wrapper
    groupWrapper = form.find('[data-attribute-name="group_id"]').closest('.form-group')
    return if groupWrapper.length is 0
    
    # Build cc_user_ids field using cc_user_select element
    ccAttribute = {
      name: 'cc_user_ids'
      display: __('CC Users')
      tag: 'cc_user_select'
      multiple: true
      null: true
      nulloption: true
      relation: 'User'
      item_class: 'column'
    }
    
    # Render the field
    ccElement = App.UiElement.cc_user_select.render(ccAttribute, params)
    
    # Wrap in form-group div
    ccHtml = $('<div class="form-group" data-attribute-name="cc_user_ids"></div>')
    ccHtml.html(ccElement)
    
    # Insert after group_id
    groupWrapper.after(ccHtml)

App.Config.set('150-FormHandlerCcInject', App.FormHandlerCcInject, 'TicketCreateFormHandler')
App.Config.set('150-FormHandlerCcInject', App.FormHandlerCcInject, 'TicketEditFormHandler')

