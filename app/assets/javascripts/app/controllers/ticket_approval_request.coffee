class App.TicketApprovalRequest extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Send Approval Request')
  buttonClass: 'btn--primary'
  head: __('Request Approval')
  buttonSubmitDisabled: true
  
  events:
    'submit form': 'submit'
    'change select[name="approver_id"]': 'toggleSubmit'

  content: ->
    # Return loading placeholder initially
    '<p class="loading">Loading approvers...</p>'

  onShown: (e) =>
    super
    # Load data after modal is shown
    @ajax(
      id:          'users_for_approval'
      type:        'GET'
      url:         "#{@apiPath}/users"
      processData: true
      success:     (data, status, xhr) =>
        @renderWithUsers(data, status, xhr)
      error:       (xhr, status, error) =>
        @renderError(xhr, status, error)
    )

  renderWithUsers: (data, status, xhr) =>
    users = if Array.isArray(data) then data else (data?.users || [])
    # Get ticket's organization ID
    ticket = App.Ticket.find(@ticket_id)
    ticket_org_id = ticket?.organization_id
    
    # Filter to only show users with "Approver" role
    current_user_id = App.User.current()?.id
    approvers = users.filter (user) ->
      # Exclude current user
      return false if user.id is current_user_id
      # Only show users with "Approver" role
      user.role_ids && user.role_ids.some (role_id) ->
        role = App.Role.find(role_id)
        role && role.name == 'Approver'

    # Update modal body content (same pattern as Translation modal)
    content = App.view('ticket_approval_request')(
      ticket_id: @ticket_id
      approvers: approvers
      error: false
    )
    @el.find('.modal-body').html(content)
    
    # Initialize searchable select for approver dropdown
    @el.find('select[name="approver_id"]').searchableSelect()
    
    @toggleSubmit()
  
  toggleSubmit: =>
    selected = @el.find('select[name="approver_id"]').val()
    if selected then @$('.js-submit').removeClass('is-disabled') else @$('.js-submit').addClass('is-disabled')

  renderError: (xhr, status, error) =>
    content = App.view('ticket_approval_request')(
      ticket_id: @ticket_id
      approvers: []
      error: true
    )
    @el.find('.modal-body').html(content)

  submit: (e) =>
    e.preventDefault()
    
    form_data = @formParam(e.currentTarget)
    
    @ajax(
      id: 'create_approval_request'
      type: 'POST'
      url: "#{@apiPath}/tickets/#{@ticket_id}/approvals"
      data: form_data
      processData: true
      contentType: 'application/x-www-form-urlencoded; charset=UTF-8'
      success: @submitSuccess
      error: @submitError
    )

  submitSuccess: (data, status, xhr) =>
    # Use custom message if provided, otherwise default
    message = data.message || __('Approval request created successfully')
    @notify(
      type: 'success'
      msg:  message
    )
    @close()
    @callback() if @callback

  submitError: (xhr, status, error) =>
    error_msg = __('Failed to create approval request')
    try
      response = JSON.parse(xhr.responseText)
      error_msg = response.error if response?.error
    catch
      error_msg = xhr.responseText || error_msg
    
    @notify(
      type: 'error'
      msg: error_msg
    )
