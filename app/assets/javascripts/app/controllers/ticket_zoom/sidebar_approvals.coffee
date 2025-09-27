class SidebarApprovals extends App.Controller
  sidebarItem: =>
    
    return if @ticket.currentView() isnt 'agent'
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'approvals'
      badgeIcon: 'checkmark'
      badgeCallback: @badgeRender
      sidebarHead: __('Approvals')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Only allow requesting approval if user is not a receiver of this ticket
    unless @isReceiver()
      @item.sidebarActions.push(
        title: __('Request Approval')
        name: 'approval-request'
        callback: @requestApproval
      )

    @item

  showPanel: (el) =>
    @elSidebar = el
    @widget = new App.WidgetApprovals(
      el:       @elSidebar
      ticket_id: @ticket.id
      parentVC: @
      callback: @refreshApprovals
    )
    
    # Load approvals data for isReceiver check
    @loadApprovalsForCheck()

  refreshApprovals: =>
    if @elSidebar
      @showPanel(@elSidebar)

  loadApprovalsForCheck: =>
    # Load approvals data for isReceiver check
    @ajax(
      id: 'load_approvals_for_check'
      type: 'GET'
      url: "#{@apiPath}/tickets/#{@ticket.id}/approvals"
      processData: true
      success: (data, status, xhr) =>
        @approvals = data?.approvals || []
      error: (xhr, status, error) =>
        @approvals = []
    )

  requestApproval: =>
    # Create approval request modal
    new App.TicketApprovalRequest(
      ticket_id: @ticket.id
      container: @elSidebar.closest('.content')
      callback: @refreshApprovals
    )

  badgeRender: (el) =>
    @badgeEl = el
    @badgeRenderLocal()

  badgeRenderLocal: =>
    @badgeEl.html(App.view('generic/sidebar_tabs_item')(
      name: 'approvals'
      icon: 'checkmark'
      counter: ''
      counterPossible: false
    ))

  isReceiver: =>
    # Check if current user is specifically requested for approval on this ticket
    current_user = App.User.current()
    return false unless current_user
    
    # Method 1: Check if user has share permissions (indicating they are a receiver)
    share_permissions = @ticket?.share_permissions
    if share_permissions && (share_permissions.read || share_permissions.comment || share_permissions.edit)
      return true
    
    # Method 2: Check if user is an approver for this ticket
    # We need to check if there are any pending approval requests for this user
    if @approvals && @approvals.length > 0
      for approval in @approvals
        if approval.status == 'pending' && approval.approver_id == current_user.id
          return true
    
    # If neither shared nor approver, they are not a receiver
    return false

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


