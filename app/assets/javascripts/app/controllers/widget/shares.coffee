class App.WidgetShares extends App.Controller
  events:
    'click .js-edit-share': 'editShare'
    'click .js-delete-share': 'deleteShare'
    'click .js-revoke-share': 'revokeShare'
    'click .js-create-share': 'openShareCreate'

  constructor: ->
    super
    @lastShares = []  # Initialize to prevent undefined errors
    @loadShares()
    @renderActions()
    
    # Listen for real-time updates from other users with debounce
    @controllerBind('TicketShare:create', (data) =>
      @delay =>
        @loadShares()
      , 500, 'share-reload'
    )
    @controllerBind('TicketShare:update', (data) =>
      @delay =>
        @loadShares()
      , 500, 'share-reload'
    )
    @controllerBind('TicketShare:destroy', (data) =>
      @delay =>
        @loadShares()
      , 500, 'share-reload'
    )

  loadShares: =>
    return if @isLoadingShares
    
    @isLoadingShares = true
    @ajax(
      id:          'load_shares'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/shares"
      processData: true
      success:     @renderShares
      error:       @renderError
      complete:    => @isLoadingShares = false
    )

  renderShares: (data, status, xhr) =>
    @lastShares = data?.shares || []
    @render(@lastShares)

  renderError: (xhr, status, error) =>
    @html '<div class="sidebar-block"><div class="alert alert-danger">Unable to load shares</div></div>'

  render: (shares) =>
    # Render the full template with real data
    current_user = App.User.current()
    current_user_id = if current_user then String(current_user.id) else 'unknown'
    
    @html App.view('widget/shares')(
      shares: shares
      ticket_id: @ticket_id
      current_user_id: current_user_id
    )

  renderActions: =>
    @parentVC?.parentSidebar?.sidebarActionsRender('shares', @parentVC?.item?.sidebarActions || [])

  openShareCreate: (e) =>
    e?.preventDefault()
    new App.TicketShareCreate(
      ticket_id: @ticket_id
      container: @el.closest('.content')
      callback:  => @loadShares()
    )


  editShare: (e) =>
    e.preventDefault()
    e.stopPropagation()
    e.stopImmediatePropagation()
    return if @__editModalOpen
    @__editModalOpen = true
    share_id = $(e.currentTarget).data('share-id')
    # Find current share data from last load
    share = (@lastShares or []).find (s) -> String(s.id) == String(share_id)

    # Safety check - if share not found, try to reload shares first
    unless share
      # Try to reload shares and find the share again
      @ajax(
        id: 'reload_share_for_edit'
        type: 'GET'
        url: "#{@apiPath}/tickets/#{@ticket_id}/shares"
        processData: true
        success: (data, status, xhr) =>
          @lastShares = data?.shares || []
          share = @lastShares.find (s) -> String(s.id) == String(share_id)
          if share
            # Found it after reload, proceed with edit
            new App.TicketShareEdit(
              share: share
              ticket_id: @ticket_id
              container: @el.closest('.content')
              parentWidget: @
              callback: => @loadShares()
            )
          else
            # Still not found, show error
            @notify(
              type: 'error'
              msg: __('Share data not found. Please refresh and try again.')
            )
          @__editModalOpen = false
        error: (xhr, status, error) =>
          @notify(
            type: 'error'
            msg: __('Share data not found. Please refresh and try again.')
          )
          @__editModalOpen = false
      )
      return

    new App.TicketShareEdit(
      share: share
      ticket_id: @ticket_id
      container: @el.closest('.content')
      parentWidget: @
      callback: => @loadShares()
    )

    @delay =>
      @__editModalOpen = false
    , 100

  deleteShare: (e) =>
    e.preventDefault()
    e.stopPropagation()
    e.stopImmediatePropagation()
    return if @_requestInFlight
    share_id = $(e.currentTarget).data('share-id')
    @setCurrentAction('delete')

    new App.ControllerConfirm(
      message: __('Are you sure you want to delete this share? This action cannot be undone.'),
      buttonClass: 'btn--danger',
      callback: =>
        @_requestInFlight = true
        @ajax(
          id: 'delete_share'
          type: 'DELETE'
          url: "#{@apiPath}/tickets/#{@ticket_id}/shares/#{share_id}"
          processData: true
          success: (data, status, xhr) =>
            @_requestInFlight = false
            @shareSuccess(data, status, xhr)
          error: (xhr, status, error) =>
            @_requestInFlight = false
            @shareError(xhr, status, error)
          complete: => @_requestInFlight = false
        )
      buttonCancel: true
      container: @el.closest('.content')
    )

  revokeShare: (e) =>
    e.preventDefault()
    e.stopPropagation()
    e.stopImmediatePropagation()
    return if @_requestInFlight
    share_id = $(e.currentTarget).data('share-id')
    @setCurrentAction('revoke')

    @_requestInFlight = true
    @ajax(
      id: 'revoke_share'
      type: 'POST'
      url: "#{@apiPath}/tickets/#{@ticket_id}/shares/#{share_id}/revoke"
      processData: true
      success: (data, status, xhr) =>
        @_requestInFlight = false
        @shareSuccess(data, status, xhr)
      error: (xhr, status, error) =>
        @_requestInFlight = false
        @shareError(xhr, status, error)
      complete: => @_requestInFlight = false
    )


  shareSuccess: (data, status, xhr) =>
    # Get the action type from the AJAX request to show appropriate message
    action = @getCurrentAction()
    if action is 'revoke'
      @notify(type: 'success', msg: __('Share revoked successfully'))
    else if action is 'delete'
      @notify(type: 'success', msg: __('Share deleted successfully'))
    else
      @notify(type: 'success', msg: __('Share updated successfully'))
    
    # Reload shares from backend
    @loadShares()
    @callback() if @callback
    @clearCurrentAction()

  shareError: (xhr, status, error) =>
    action = @getCurrentAction()
    if action is 'revoke'
      @notify(type: 'error', msg: __('Failed to revoke share'))
    else if action is 'delete'
      @notify(type: 'error', msg: __('Failed to delete share'))
    else
      @notify(type: 'error', msg: __('Failed to update share'))
    @clearCurrentAction()

  getCurrentAction: =>
    @currentAction

  setCurrentAction: (action) =>
    @currentAction = action

  clearCurrentAction: =>
    @currentAction = null


  refresh: =>
    if @callback
      @callback()

  reload: =>
    @loadShares()
