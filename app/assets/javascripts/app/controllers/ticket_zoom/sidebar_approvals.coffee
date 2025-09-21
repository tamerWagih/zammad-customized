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
    @loadApprovals()

  loadApprovals: =>
    # For now, show placeholder content
    # TODO: Load actual approval data from backend
    @html $(App.view('ticket_zoom/sidebar_approvals')({
      approvals: []
    }))

  requestApproval: =>
    # TODO: Implement approval request modal/form
    @notify(
      type: 'info'
      msg: __('Approval request functionality will be implemented')
    )

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


