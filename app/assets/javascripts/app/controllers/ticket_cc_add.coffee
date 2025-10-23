class App.TicketCcAdd extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Add CC')
  head: __('Add CC User')
  large: true

  content: =>
    configure_attributes = [
      {
        name:       'user_id'
        display:    __('User')
        tag:        'cc_user_select'
        multiple:   false
        null:       false
        translate:  false
      },
      {
        name:       'message'
        display:    __('Message (optional)')
        tag:        'textarea'
        rows:       3
        limit:      500
        null:       true
        placeholder: __('Optional note about why this user is being CC\'d...')
      },
    ]

    new App.ControllerForm(
      el:        @formElement
      model:
        configure_attributes: configure_attributes
        className: 'TicketCc'
      autofocus: true
    )

  onSubmit: (e) =>
    e.preventDefault()

    # Get form data
    params = @formParam(e.target)

    # Validate
    if !params.user_id
      @formEnable(e)
      @notify(
        type: 'error'
        msg: __('Please select a user')
      )
      return

    @ajax(
      id:   'add_cc'
      type: 'POST'
      url:  "#{@apiPath}/tickets/#{@ticket_id}/ccs"
      data: JSON.stringify(params)
      processData: false
      success: (data, status, xhr) =>
        @close()
        @callback() if @callback
        @notify(
          type: 'success'
          msg:  __('CC user added successfully')
        )
      error: (xhr, status, error) =>
        @formEnable(e)
        details = xhr.responseJSON?.error || xhr.responseText || error
        @notify(
          type: 'error'
          msg:  App.i18n.translateContent('Failed to add CC user: %s', details)
        )
    )

