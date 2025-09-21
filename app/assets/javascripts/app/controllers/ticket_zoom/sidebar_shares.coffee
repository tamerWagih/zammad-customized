class SidebarShares extends App.Controller
  sidebarItem: =>
    return if @ticket.currentView() isnt 'agent'
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'shares'
      badgeIcon: 'share'
      sidebarHead: __('Shares')
      sidebarCallback: @showPanel
      sidebarActions: []
    }
    @item

  showPanel: (el) =>
    @elSidebar = el
    @html $(App.view('ticket_zoom/sidebar_shares')())

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')


