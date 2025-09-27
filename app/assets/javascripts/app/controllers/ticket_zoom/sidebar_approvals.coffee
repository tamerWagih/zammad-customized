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

  refreshApprovals: =>
    if @elSidebar
      @showPanel(@elSidebar)

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
    # Check if current user is specifically shared with this ticket
    current_user = App.User.current()
    return false unless current_user
    
    # Check if user has share permissions for this specific ticket (indicating they are a receiver)
    share_permissions = @ticket?.share_permissions
    if share_permissions && (share_permissions.read || share_permissions.comment || share_permissions.edit)
      return true
    
    # If no share permissions, they are not a receiver
    return false

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


