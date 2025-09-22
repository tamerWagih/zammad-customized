class App.TicketApprovalRequest extends App.ControllerModal
  events:
    'submit form': 'submit'

  constructor: ->
    super
    @render()

  render: =>
    # Get available users for approval
    @ajax(
      id:          'users_for_approval'
      type:        'GET'
      url:         "#{@apiPath}/users"
      processData: true
      success:     @renderWithUsers
      error:       @renderError
    )

  renderWithUsers: (data, status, xhr) =>
    users = data?.users || []
    # Filter to only show agents/admins and exclude current user
    current_user_id = App.User.current()?.id
    approvers = users.filter (user) ->
      # Exclude current user
      return false if user.id is current_user_id
      # Only show agents and admins
      user.role_ids && user.role_ids.some (role_id) ->
        role = App.Role.find(role_id)
        role && (role.name == 'Agent' || role.name == 'Admin')

    @html $(App.view('ticket_approval_request')({
      ticket_id: @ticket_id
      approvers: approvers
    }))

  renderError: (xhr, status, error) =>
    @html $(App.view('ticket_approval_request')({
      ticket_id: @ticket_id
      approvers: []
      error: true
    }))

  submit: (e) =>
    e.preventDefault()
    
    form_data = @formParam(e.currentTarget)
    
    @ajax(
      id:          'create_approval_request'
      type:        'POST'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals"
      data:        JSON.stringify(form_data)
      processData: false
      contentType: 'application/json'
      success:     @submitSuccess
      error:       @submitError
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
