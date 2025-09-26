class App.TicketShareCreate extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Share Ticket')
  buttonClass: 'btn--primary'
  head: __('Share Ticket')
  buttonSubmitDisabled: true
  
  events:
    'submit form': 'submit'
    'change select[name="shared_with_id"]': 'toggleSubmit'


  content: ->
    # Get available users for sharing
    @ajax(
      id:          'users_for_sharing'
      type:        'GET'
      url:         "#{@apiPath}/users"
      processData: true
      success:     (data, status, xhr) =>
        @renderWithUsers(data, status, xhr)
      error:       (xhr, status, error) =>
        @renderError(xhr, status, error)
    )
    # Return loading content initially
    '<p>Loading users...</p>'


  renderWithUsers: (data, status, xhr) =>
    users = if Array.isArray(data) then data else (data?.users || [])
    # Only Admins and Agents are valid share targets
    current_user_id = App.User.current()?.id

    resolveRoleNames = (user) ->
      names = []
      # If API provided role_ids, resolve via App.Role store
      if Array.isArray(user.role_ids)
        for rid in user.role_ids
          role = App.Role.find(rid)
          names.push(role.name) if role?.name
      # If API provided roles as objects or strings, include their names
      if Array.isArray(user.roles)
        for r in user.roles
          if typeof r is 'string'
            names.push(r)
          else if r?.name
            names.push(r.name)
      # Deduplicate
      _.uniq(names)

    available_users = users.filter (user) ->
      return false if user.id is current_user_id
      roleNames = resolveRoleNames(user)
      hasAgentOrAdmin = roleNames.includes('Agent') or roleNames.includes('Admin')
      return !!hasAgentOrAdmin && user.active isnt false

    # Update modal content
    @el.find('.modal-body').html(App.view('ticket_share_create')({
      ticket_id: @ticket_id
      users: available_users
    }))
    @toggleSubmit()
  toggleSubmit: =>
    selected = @el.find('select[name="shared_with_id"]').val()
    if selected then @$('.js-submit').removeClass('is-disabled') else @$('.js-submit').addClass('is-disabled')

  renderError: (xhr, status, error) =>
    @el.find('.modal-body').html(App.view('ticket_share_create')({
      ticket_id: @ticket_id
      users: []
      error: true
    }))

  submit: (e) =>
    e.preventDefault()
    
    form_data = @formParam(e.currentTarget)
    
    # Ensure permissions is always an array
    if form_data.permissions and typeof form_data.permissions is 'string'
      form_data.permissions = [form_data.permissions]
    
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
