# Inject CC Users field into ticket creation form
class App.FormHandlerCcInject
  @run: (params, attribute, attributes, classname, form, ui) ->
    console.log '[CC_INJECT] Form handler called - classname:', classname
    console.log '[CC_INJECT] Form exists:', form?.length
    console.log '[CC_INJECT] Params ticket_id:', params?.ticket_id
    
    # For ticket creation, params.ticket_id is undefined
    # For ticket edit, params.ticket_id has a value
    return if params?.ticket_id  # Skip if editing existing ticket

    console.log '[CC_INJECT] Running for ticket creation...'

    # Check if already injected
    existing = form.find('[name="cc_user_ids"]')
    console.log '[CC_INJECT] Existing CC field:', existing.length
    return if existing.length > 0

    # Find group field
    groupWrapper = form.find('[data-attribute-name="group_id"]').closest('.form-group')
    console.log '[CC_INJECT] Group wrapper found:', groupWrapper.length
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
    console.log '[CC_INJECT] Rendering CC field...'
    ccElement = App.UiElement.cc_user_select.render(ccAttribute, params)
    console.log '[CC_INJECT] CC element created:', ccElement?.length
    
    ccHtml = $('<div class="form-group" data-attribute-name="cc_user_ids"></div>')
    ccHtml.html(ccElement)

    # Insert after group
    groupWrapper.after(ccHtml)
    console.log '[CC_INJECT] ✅ CC field injected successfully!'

# Register for ticket creation
App.Config.set('150-FormHandlerCcInject', App.FormHandlerCcInject, 'TicketCreateFormHandler')
console.log '[CC_INJECT] Form handler registered for TicketCreateFormHandler'

