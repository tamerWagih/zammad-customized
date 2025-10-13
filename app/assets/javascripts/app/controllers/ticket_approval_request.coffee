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
    # Find Approver role ID
    approverRole = App.Role.findByAttribute('name', 'Approver')
    if !approverRole
      @renderError(null, null, 'Approver role not found')
      return
    
    # Load only users with Approver role from backend (efficient!)
    @ajax(
      id:          'users_for_approval'
      type:        'GET'
      url:         "#{@apiPath}/users/search"
      data:
        role_ids: [approverRole.id]  # Backend filters by Approver role
        limit: 1000
      processData: true
      success:     (data, status, xhr) =>
        @renderWithUsers(data, status, xhr)
      error:       (xhr, status, error) =>
        @renderError(xhr, status, error)
    )

  renderWithUsers: (data, status, xhr) =>
    users = if Array.isArray(data) then data else (data?.users || [])
    
    # Backend already filtered by Approver role
    # Just exclude current user and inactive users
    current_user_id = App.User.current()?.id
    approvers = users.filter (user) ->
      return false if user.id is current_user_id  # Exclude current user
      return false if user.active is false        # Exclude inactive users
      true

    # Update modal body content (same pattern as Translation modal)
    content = App.view('ticket_approval_request')(
      ticket_id: @ticket_id
      approvers: approvers
      error: false
    )
    @el.find('.modal-body').html(content)
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
