class SidebarApprovals extends App.Controller
  sidebarItem: =>
    return if @ticket.currentView() isnt 'agent'
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'approvals'
      badgeIcon: 'checkmark'
      sidebarHead: __('Approvals')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Add action to create new approval request
    @item.sidebarActions.push
      title: __('Request Approval')
      name: 'approval-request'
      callback: @requestApproval

    @item

  showPanel: (el) =>
    @elSidebar = el
    console.log('SidebarApprovals showPanel called', el, @ticket)
    new App.WidgetApprovals(
      el:       @elSidebar
      ticket_id: @ticket.id
      callback: @refreshApprovals
    )

  refreshApprovals: =>
    if @elSidebar
      @showPanel(@elSidebar)

  requestApproval: =>
    # Create approval request modal
    new App.TicketApprovalRequest(
      ticket_id: @ticket.id
      container: @elSidebar.closest('.content')
      callback:  @refreshApprovals
    )

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


