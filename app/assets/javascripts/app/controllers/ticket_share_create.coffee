class App.TicketShareCreate extends App.ControllerModal
  events:
    'submit form': 'submit'

  constructor: ->
    super
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
    users = data?.users || []
    # Filter to exclude current user
    current_user_id = App.User.current()?.id
    available_users = users.filter (user) ->
      # Exclude current user
      return false if user.id is current_user_id
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
      id:          'create_ticket_share'
      type:        'POST'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/shares"
      data:        JSON.stringify(form_data)
      processData: false
      contentType: 'application/json'
      success:     @submitSuccess
      error:       @submitError
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
