class App.WidgetCcs extends App.Controller
  events:
    'click .js-add-cc': 'addCc'
    'click .js-delete-cc': 'deleteCc'

  constructor: ->
    super

    # STANDARD PATTERN: Use data from parent if provided (same as WidgetApprovals)
    if @ccs
      @localCcs = _.clone(@ccs)
      @render()
      return

    # Fallback: Fetch from API if not provided
    @fetch()

  fetch: =>
    return unless @ticket_id

    @ajax(
      id:          'load_ccs'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/ccs"
      processData: true
      success:     (data) =>
        @localCcs = data?.ccs || []
        @render()
      error: (xhr, status, error) =>
        console.error 'Failed to load CCs:', status, error
        @localCcs = []
        @render()
    )

  reload: (ccs) =>
    # ONLY PROTECTION: Skip if data unchanged (Zammad WidgetApprovals pattern)
    if @localCcs && _.isEqual(@localCcs, ccs)
      return

    # Data is different → update immediately
    @localCcs = _.clone(ccs)
    @stopLoading()
    @render()

  render: =>
    # Prevent unnecessary re-renders (same as WidgetApprovals)
    return if @lastLocalCcs && _.isEqual(@lastLocalCcs, @localCcs)
    @lastLocalCcs = _.clone(@localCcs)

    current_user = App.User.current()
    # Clone data before modification to prevent mutation
    ccs_data = _.map(@localCcs || [], (c) -> _.clone(c))

    # Refresh ticket for permission checks
    if @ticket_id
      @ticket = App.Ticket.findNative(@ticket_id) || App.Ticket.fullLocal(@ticket_id)

    # Check if current user can manage CCs
    can_manage = @ticket && @ticket.editable && @ticket.editable()

    # Prepare display data
    for cc in ccs_data
      cc.can_manage = can_manage
      cc.is_current_user = current_user && parseInt(cc.user_id) is parseInt(current_user.id)

      # Format dates
      if cc.created_at
        cc.created_at_formatted = App.i18n.translateTimestamp(cc.created_at)

    @html App.view('widget/ccs')(
      ccs: ccs_data
      ticket_id: @ticket_id
      current_user_id: current_user.id.toString()
    )

  addCc: (e) =>
    e.preventDefault()
    new App.TicketCcAdd(
      ticket_id: @ticket_id
      callback: =>
        # NO fetch() call - WebSocket will update
    )

  deleteCc: (e) =>
    e.preventDefault()
    cc_id = $(e.currentTarget).data('id')
    return unless cc_id

    new App.ControllerConfirm(
      message: __('Are you sure you want to remove this CC?')
      callback: =>
        @performDelete(cc_id)
      container: @el.closest('.content')
    )

  performDelete: (cc_id) =>
    @startLoading()

    @ajax(
      id:   'delete_cc'
      type: 'DELETE'
      url:  "#{@apiPath}/tickets/#{@ticket_id}/ccs/#{cc_id}"
      processData: true
      success: (data) =>
        # NO optimistic update - let WebSocket handle it
        @stopLoading()
      error: (xhr, status, error) =>
        @stopLoading()
        console.error 'Failed to delete CC:', status, error
        @notify(
          type: 'error'
          msg: App.i18n.translateContent('Failed to delete CC.')
        )
    )

  startLoading: =>
    @el.find('.js-loading').removeClass('hide')

  stopLoading: =>
    @el.find('.js-loading').addClass('hide')

