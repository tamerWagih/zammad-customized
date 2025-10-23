# Inject CC Users field into ticket creation form
class App.FormHandlerCcInject
  @run: (params, attribute, attributes, classname, form, ui) ->
    return if classname isnt 'create'

    # Check if already injected
    return if form.find('[name="cc_user_ids"]').length > 0

    # Find group field
    groupWrapper = form.find('[data-attribute-name="group_id"]').closest('.form-group')
    return if groupWrapper.length is 0

    # Build CC attribute
    ccAttribute = {
      name: 'cc_user_ids'
      display: __('CC')
      tag: 'cc_user_select'
      multiple: true
      null: true
      nulloption: true
      item_class: 'column'
      relation: 'User'
    }

    # Render field
    ccElement = App.UiElement.cc_user_select.render(ccAttribute, params)
    ccHtml = $('<div class="form-group" data-attribute-name="cc_user_ids"></div>')
    ccHtml.html(ccElement)

    # Insert after group
    groupWrapper.after(ccHtml)

# Register for ticket creation
App.Config.set('150-FormHandlerCcInject', App.FormHandlerCcInject, 'TicketCreateFormHandler')

