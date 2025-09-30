class SidebarApprovals extends App.Controller
  constructor: ->
    super
    @last_can_share = null

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

    # Only allow requesting approval if user is owner or has share access
    if @canShareOrApprove()
      @item.sidebarActions.push(
        title: __('Request Approval')
        name: 'approval-request'
        callback: @requestApproval
      )

    @item

  showPanel: (el) =>
    @elSidebar = el
    console.log 'Showing approvals panel for ticket:', @ticket?.id
    
    # Destroy existing widget if any
    if @widget
      @widget.destroy?()
    
    @widget = new App.WidgetApprovals(
      el:       @elSidebar
      ticket_id: @ticket.id
      parentVC: @
      callback: @refreshApprovals
    )
    
    # Load approvals data for isReceiver check
    @loadApprovalsForCheck()
    
    # Ensure widget loads data when panel is shown
    @delay =>
      if @widget && @widget.reload
        console.log 'Reloading approvals widget'
        @widget.reload()
    , 200, 'approval-panel-show'

  # Standard reload method called by sidebar system
  reload: (args) =>
    if @widget && @widget.reload
      @widget.reload(args)
    else if @elSidebar
      @showPanel(@elSidebar)
    
    # Check if ticket assignment changed and trigger sidebar re-render
    @checkAndUpdateActions()

  checkAndUpdateActions: =>
    # Check if the ability to share/approve has changed
    current_can_share = @canShareOrApprove()
    if @last_can_share isnt current_can_share
      @last_can_share = current_can_share
      # Trigger sidebar re-render to update actions
      App.Event.trigger('ui::ticket::sidebarRerender', { taskKey: @taskKey })

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

  canShareOrApprove: =>
    # Check if current user can share or request approval
    current_user = App.User.current()
    return false unless current_user
    
    # Only owner can share and request approval (prevents circular requests)
    if @ticket?.owner_id && String(@ticket.owner_id) == String(current_user.id)
      return true
    
    # Allow users with full access permission from share, if not expired
    share_permissions = @ticket?.share_permissions
    is_expired = false
    if @ticket?.share_expires_at
      try
        is_expired = new Date(@ticket.share_expires_at) <= new Date()
      catch
        is_expired = false
    if share_permissions && share_permissions.edit && !is_expired
      return true
    
    # Everyone else cannot share or request approval
    return false

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


