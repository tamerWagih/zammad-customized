class App.TicketApprovalRequest extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Send Approval Request')
  buttonClass: 'btn--primary'
  head: __('Request Approval')
  
  events:
    'submit form': 'submit'


  content: ->
    console.log('App.TicketApprovalRequest content called')
    # Get available users for approval
    @ajax(
      id:          'users_for_approval'
      type:        'GET'
      url:         "#{@apiPath}/users"
      processData: true
      success:     (data, status, xhr) =>
        console.log('Users AJAX success:', data)
        @renderWithUsers(data, status, xhr)
      error:       (xhr, status, error) =>
        console.log('Users AJAX error:', error, xhr.responseText)
        @renderError(xhr, status, error)
    )
    # Return loading content initially
    '<p>Loading approvers...</p>'


  renderWithUsers: (data, status, xhr) =>
    console.log('App.TicketApprovalRequest renderWithUsers called')
    users = if Array.isArray(data) then data else (data?.users || [])
    # Get ticket's organization ID
    ticket = App.Ticket.find(@ticket_id)
    ticket_org_id = ticket?.organization_id
    
    # Filter to only show agents/admins from the same organization
    current_user_id = App.User.current()?.id
    approvers = users.filter (user) ->
      # Exclude current user
      return false if user.id is current_user_id
      # Only show users from the same organization as the ticket
      return false unless ticket_org_id && user.organization_id == ticket_org_id
      # Only show agents and admins
      user.role_ids && user.role_ids.some (role_id) ->
        role = App.Role.find(role_id)
        role && (role.name == 'Agent' || role.name == 'Admin')

    console.log('Filtered approvers:', approvers)
    console.log('Modal element:', @el)

    # Update modal content
    content = App.view('ticket_approval_request')({
      ticket_id: @ticket_id
      approvers: approvers
    })
    console.log('Generated content:', content)
    
    @el.find('.modal-body').html(content)

  renderError: (xhr, status, error) =>
    @el.find('.modal-body').html(App.view('ticket_approval_request')({
      ticket_id: @ticket_id
      approvers: []
      error: true
    }))

  submit: (e) =>
    e.preventDefault()
    
    form_data = @formParam(e.currentTarget)
    
    @ajax(
      id: 'create_approval_request'
      type: 'POST'
      url: "#{@apiPath}/tickets/#{@ticket_id}/approvals"
      data: JSON.stringify(form_data)
      processData: false
      contentType: 'application/json'
      success: @submitSuccess
      error: @submitError
    )

  submitSuccess: (data, status, xhr) =>
    @notify(
      type: 'success'
      msg:  __('Approval request created successfully')
    )
    @close()
    @callback() if @callback

  submitError: (xhr, status, error) =>
    @notify(
      type: 'error'
      msg:  __('Failed to create approval request')
    )
