class App.TicketShareCreate extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Share Ticket')
  buttonClass: 'btn--primary'
  head: __('Share Ticket')
  shown: true
  
  events:
    'submit form': 'submit'

  constructor: ->
    console.log('App.TicketShareCreate constructor called')
    super

  content: =>
    # Return the modal content
    @render()

  render: =>
    # Get available users for sharing
    @ajax(
      id:          'users_for_sharing'
      type:        'GET'
      url:         "#{@apiPath}/users"
      processData: true
      success:     @renderWithUsers
      error:       @renderError
    )

  renderWithUsers: (data, status, xhr) =>
    users = if Array.isArray(data) then data else (data?.users || [])
    # Get ticket's organization ID
    ticket = App.Ticket.find(@ticket_id)
    ticket_org_id = ticket?.organization_id
    
    # Filter to only show users from the same organization
    current_user_id = App.User.current()?.id
    available_users = users.filter (user) ->
      # Exclude current user
      return false if user.id is current_user_id
      # Only show users from the same organization as the ticket
      return false unless ticket_org_id && user.organization_id == ticket_org_id
      # Include all active users
      return user.active isnt false

    @html $(App.view('ticket_share_create')({
      ticket_id: @ticket_id
      users: available_users
    }))

  renderError: (xhr, status, error) =>
    @html $(App.view('ticket_share_create')({
      ticket_id: @ticket_id
      users: []
      error: true
    }))

  submit: (e) =>
    e.preventDefault()
    
    form_data = @formParam(e.currentTarget)
    
    @ajax(
      id: 'create_ticket_share'
      type: 'POST'
      url: "#{@apiPath}/tickets/#{@ticket_id}/shares"
      data: JSON.stringify(form_data)
      processData: false
      contentType: 'application/json'
      success: @submitSuccess
      error: @submitError
    )

  submitSuccess: (data, status, xhr) =>
    @notify(
      type: 'success'
      msg:  __('Ticket shared successfully')
    )
    @close()
    @callback() if @callback

  submitError: (xhr, status, error) =>
    @notify(
      type: 'error'
      msg:  __('Failed to share ticket')
    )
