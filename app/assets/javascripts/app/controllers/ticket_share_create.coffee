class App.TicketShareCreate extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Share Ticket')
  buttonClass: 'btn--primary'
  head: __('Share Ticket')
  buttonSubmitDisabled: true
  
  events:
    'submit form': 'submit'
    'change select[name="group_id"]': 'toggleSubmit'

  content: ->
    # Return loading placeholder initially
    '<p class="loading">Loading groups...</p>'

  onShown: (e) =>
    super
    # Load data after modal is shown
    @ajax(
      id:          'groups_for_sharing'
      type:        'GET'
      url:         "#{@apiPath}/groups"
      processData: true
      success:     (data, status, xhr) =>
        @renderWithGroups(data)
      error:       (xhr, status, error) =>
        @renderError(xhr, status, error)
    )

  renderWithGroups: (data) ->
    groups = if Array.isArray(data) then data else (data?.groups || [])
    groups = groups.filter (group) -> group?.active isnt false
    
    # Filter out the ticket's current group (requester's group already has access)
    ticket = App.Ticket.find(@ticket_id)
    if ticket?.group_id
      groups = groups.filter (group) -> group.id.toString() isnt ticket.group_id.toString()
    
    groups = groups.sort (a, b) ->
      nameA = (a.fullname || a.name || '').toLowerCase()
      nameB = (b.fullname || b.name || '').toLowerCase()
      if nameA < nameB then -1 else if nameA > nameB then 1 else 0

    # Update modal body content (same pattern as Translation modal)
    content = App.view('ticket_share_create')(
      ticket_id: @ticket_id
      groups: groups
      error: false
    )
    @el.find('.modal-body').html(content)
    @toggleSubmit()

  toggleSubmit: =>
    selected = @el.find('select[name="group_id"]').val()
    if selected
      @$('.js-submit').removeClass('is-disabled')
    else
      @$('.js-submit').addClass('is-disabled')

  renderError: (xhr, status, error) =>
    content = App.view('ticket_share_create')(
      ticket_id: @ticket_id
      groups: []
      error: true
    )
    @el.find('.modal-body').html(content)

  submit: (e) =>
    e.preventDefault()
    
    form_data = @formParam(e.currentTarget)
    
    if form_data.expires_at
      try
        form_data.expires_at = new Date(form_data.expires_at).toISOString().slice(0, 10)
      catch
        form_data.expires_at = ''
    
    @ajax(
      id: 'create_ticket_share'
      type: 'POST'
      url: "#{@apiPath}/tickets/#{@ticket_id}/shares"
      data: form_data
      processData: true
      contentType: 'application/x-www-form-urlencoded; charset=UTF-8'
      success: @submitSuccess
      error: @submitError
    )

  submitSuccess: (data, status, xhr) =>
    share = data?.share
    message = if share?.group_name
      __('Ticket shared with group %s').replace('%s', share.group_name)
    else
      __('Ticket shared successfully')

    @notify(
      type: 'success'
      msg:  message
    )
    @close()
    @callback() if @callback

  submitError: (xhr, status, error) =>
    error_msg = __('Failed to share ticket')
    try
      response = JSON.parse(xhr.responseText)
      error_msg = response.error if response?.error
    catch
      error_msg = xhr.responseText || error_msg
    
    @notify(
      type: 'error'
      msg: error_msg
    )

