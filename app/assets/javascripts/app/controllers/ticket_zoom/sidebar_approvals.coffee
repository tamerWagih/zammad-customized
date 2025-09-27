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
    # Check if current user is a receiver of a share or approval for this ticket
    current_user = App.User.current()
    return false unless current_user
    
    # Method 1: Check if user has share permissions (indicating they are a receiver)
    share_permissions = @ticket?.share_permissions
    if share_permissions && (share_permissions.read || share_permissions.comment || share_permissions.edit)
      return true
    
    # Method 2: Check if user is the ticket owner (owners can always request approval)
    if @ticket?.owner_id && String(@ticket.owner_id) == String(current_user.id)
      return false
    
    # Method 3: Check if user is in the same organization as owner (agents/admins can request approval)
    if @ticket?.organization_id && current_user.organization_id && 
       String(@ticket.organization_id) == String(current_user.organization_id)
      return false
    
    # Method 4: Check if user has ticket.agent permission (agents can request approval)
    if current_user.permissions && current_user.permissions.indexOf('ticket.agent') >= 0
      return false
    
    # If none of the above, they might be a receiver
    return true

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


