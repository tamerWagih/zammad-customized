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
    new App.WidgetShares(
      el:       @elSidebar
      ticket:   @ticket
      callback: @refreshShares
    )

  refreshShares: =>
    if @elSidebar
      @showPanel(@elSidebar)

  createShare: =>
    # Create share modal
    new App.TicketShareCreate(
      ticket_id: @ticket.id
      container: @elSidebar.closest('.content')
      callback:  @refreshShares
    )

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')


