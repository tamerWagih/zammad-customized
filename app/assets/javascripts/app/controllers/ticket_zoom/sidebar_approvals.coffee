class SidebarApprovals extends App.Controller
  sidebarItem: =>
    return if @ticket.currentView() isnt 'agent'
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'approvals'
      badgeIcon: 'checklist'
      sidebarHead: __('Approvals')
      sidebarCallback: @showPanel
      sidebarActions: []
    }
    @item

  showPanel: (el) =>
    @elSidebar = el
    @html $(App.view('ticket_zoom/sidebar_approvals')())

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


