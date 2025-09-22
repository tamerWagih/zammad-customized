class SidebarShares extends App.Controller
  sidebarItem: =>
    return if @ticket.currentView() isnt 'agent'
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'shares'
      badgeIcon: 'team'
      sidebarHead: __('Shares')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Add action to create new share
    @item.sidebarActions.push
      title: __('Share Ticket')
      name: 'share-create'
      callback: @createShare

    @item

  showPanel: (el) =>
    @elSidebar = el
    @loadShares()

  loadShares: =>
    # Load share data from backend
    @ajax(
      id:          'ticket_shares'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket.id}/shares"
      processData: true
      success:     @loadSharesSuccess
      error:       @loadSharesError
    )

  loadSharesSuccess: (data, status, xhr) =>
    shares = data?.shares || []
    
    # Create interactive shares widget
    new App.WidgetShares(
      el:        @elSidebar
      ticket_id: @ticket.id
      shares:    shares
      callback:  @refreshShares
    )

  loadSharesError: (xhr, status, error) =>
    # Fallback to placeholder content if API not available
    @html $(App.view('ticket_zoom/sidebar_shares')({
      shares: []
      error: true
    }))

  refreshShares: =>
    @loadShares()

  createShare: =>
    # Create share modal
    new App.TicketShareCreate(
      ticket_id: @ticket.id
      container: @elSidebar.closest('.content')
      callback:  @refreshShares
    )

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')


