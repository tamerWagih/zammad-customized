# Inject CC Users field into ticket creation form
# Only shows CC field to users with agent or customer permissions
# Available to: Agents and Customers (for ticket sharing)
# CC dropdown includes: ONLY agents and customers (excludes admins and other roles)
# Excludes: The ticket creator and users with admin permissions
# Note: CC grants ticket access regardless of group permissions
class App.FormHandlerCcInject
  @run: (params, attribute, attributes, classname, form, ui) ->
    console.log '[CC_INJECT] ===== FORM HANDLER CALLED ====='
    console.log '[CC_INJECT] Class name:', classname
    console.log '[CC_INJECT] Attribute name:', attribute.name
    console.log '[CC_INJECT] Form exists:', form.length
    console.log '[CC_INJECT] All attributes:', Object.keys(attributes)

    return if classname isnt 'create'  # Only on ticket creation

    console.log '[CC_INJECT] Form handler called for:', attribute.name
    console.log '[CC_INJECT] Class name:', classname
    console.log '[CC_INJECT] Available form fields:', form.find('[data-attribute-name]').map(-> $(this).attr('data-attribute-name')).get()

    # Check if already injected
    existingCc = form.find('[name="cc_user_ids"]')
    console.log '[CC_INJECT] Existing CC field found:', existingCc.length
    return if existingCc.length > 0

    # Find group_id wrapper - try multiple selectors
    groupWrapper = form.find('[data-attribute-name="group_id"]').closest('.form-group')
    if groupWrapper.length is 0
      # Try alternative selectors
      groupWrapper = form.find('[name="group_id"]').closest('.form-group')
    if groupWrapper.length is 0
      # Try finding any group-related field
      groupWrapper = form.find('[data-attribute-name*="group"]').closest('.form-group')

    console.log '[CC_INJECT] Group wrapper found:', groupWrapper.length
    console.log '[CC_INJECT] Group wrapper HTML:', groupWrapper.html() if groupWrapper.length > 0
    return if groupWrapper.length is 0

    # Build cc_user_ids field using cc_user_select element
    # Only show CC field to users with ticket access permissions
    ccAttribute = {
      name: 'cc_user_ids'
      display: __('CC Users')
      tag: 'cc_user_select'
      multiple: true
      null: true
      nulloption: true
      # Remove relation to prevent conflict with API loading
      item_class: 'column'
      # Add hint for users about what types of users are available
      help: __('Search and select agents and customers to share ticket access with (excludes administrators)')
    }

    console.log '[CC_INJECT] CC Attribute:', ccAttribute

    # Render the field
    ccElement = App.UiElement.cc_user_select.render(ccAttribute, params)
    console.log '[CC_INJECT] CC Element rendered:', ccElement?.length

    # Wrap in form-group div
    ccHtml = $('<div class="form-group" data-attribute-name="cc_user_ids"></div>')
    ccHtml.html(ccElement)

    # Insert after group_id
    groupWrapper.after(ccHtml)

    console.log '[CC_INJECT] CC field injected successfully'

# Only register for ticket creation - not for editing
console.log '[CC_INJECT] Registering form handler for TicketCreateFormHandler'
App.Config.set('150-FormHandlerCcInject', App.FormHandlerCcInject, 'TicketCreateFormHandler')
console.log '[CC_INJECT] Form handler registered successfully'

