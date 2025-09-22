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
    # Load approval data from backend
    @ajax(
      id:          'ticket_approvals'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket.id}/approvals"
      processData: true
      success:     @loadApprovalsSuccess
      error:       @loadApprovalsError
    )

  loadApprovalsSuccess: (data, status, xhr) =>
    approvals = data?.approvals || []
    
    # Create interactive approval widget
    new App.WidgetApprovals(
      el:        @elSidebar
      ticket_id: @ticket.id
      approvals: approvals
      callback:  @refreshApprovals
    )

  loadApprovalsError: (xhr, status, error) =>
    # Fallback to placeholder content if API not available
    @html $(App.view('ticket_zoom/sidebar_approvals')({
      approvals: []
      error: true
    }))

  refreshApprovals: =>
    @loadApprovals()

  requestApproval: =>
    # Create approval request modal
    new App.TicketApprovalRequest(
      ticket_id: @ticket.id
      container: @elSidebar.closest('.content')
      callback:  @refreshApprovals
    )

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


