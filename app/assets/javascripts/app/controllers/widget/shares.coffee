class App.WidgetShares extends App.Controller
  events:
    'click .js-edit-share': 'editShare'
    'click .js-delete-share': 'deleteShare'
    'click .js-revoke-share': 'revokeShare'
    'click .js-create-share': 'openShareCreate'

  constructor: ->
    super
    @loadShares()
    @renderActions()

  loadShares: =>
    
    @ajax(
      id:          'load_shares'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/shares"
      processData: true
      success:     @renderShares
      error:       @renderError
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
    share_id = $(e.currentTarget).data('share-id')
    # Find current share data from last load
    share = (@lastShares or []).find (s) -> String(s.id) == String(share_id)

    new App.TicketShareEdit(
      share: share
      ticket_id: @ticket_id
      container: @el.closest('.content')
      callback: => @loadShares()
    )

  deleteShare: (e) =>
    e.preventDefault()
    share_id = $(e.currentTarget).data('share-id')
    @setCurrentAction('delete')

    @ajax(
      id: 'delete_share'
      type: 'DELETE'
      url: "#{@apiPath}/tickets/#{@ticket_id}/shares/#{share_id}"
      processData: true
      success: @shareSuccess
      error: @shareError
    )

  revokeShare: (e) =>
    e.preventDefault()
    share_id = $(e.currentTarget).data('share-id')
    @setCurrentAction('revoke')

    @ajax(
      id: 'revoke_share'
      type: 'POST'
      url: "#{@apiPath}/tickets/#{@ticket_id}/shares/#{share_id}/revoke"
      processData: true
      success: @shareSuccess
      error: @shareError
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
