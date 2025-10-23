# Inject CC Users field into ticket creation form
# Available to: Agents and Customers
# CC dropdown includes: ONLY agents and customers (excludes admins)
class App.FormHandlerCcInject
  @run: (params, attribute, attributes, classname, form, ui) ->
    return if classname isnt 'create'  # Only on ticket creation

    # Check if already injected
    existingCc = form.find('[name="cc_user_ids"]')
    return if existingCc.length > 0

    # Find group_id wrapper
    groupWrapper = form.find('[data-attribute-name="group_id"]').closest('.form-group')
    if groupWrapper.length is 0
      groupWrapper = form.find('[name="group_id"]').closest('.form-group')
    if groupWrapper.length is 0
      groupWrapper = form.find('[data-attribute-name*="group"]').closest('.form-group')

    return if groupWrapper.length is 0

    # Build cc_user_ids field using cc_user_select element
    ccAttribute = {
      name: 'cc_user_ids'
      display: __('CC Users')
      tag: 'cc_user_select'
      multiple: true
      null: true
      nulloption: true
      item_class: 'column'
      help: __('Search and select agents and customers to share ticket access with (excludes administrators)')
    }

    # Render the field
    ccElement = App.UiElement.cc_user_select.render(ccAttribute, params)

    # Wrap in form-group div
    ccHtml = $('<div class="form-group" data-attribute-name="cc_user_ids"></div>')
    ccHtml.html(ccElement)

    # Insert after group_id
    groupWrapper.after(ccHtml)

# Register for ticket creation
App.Config.set('150-FormHandlerCcInject', App.FormHandlerCcInject, 'TicketCreateFormHandler')
