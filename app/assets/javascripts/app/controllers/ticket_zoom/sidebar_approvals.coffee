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

    # Add action to create new approval request
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
    
    # Set up periodic refresh to catch changes from other users
    @startPeriodicRefresh()

  startPeriodicRefresh: =>
    # Refresh every 30 seconds when panel is active
    @stopPeriodicRefresh()
    @refreshInterval = setInterval =>
      if @widget?.reload
        @widget.reload()
    , 30000

  stopPeriodicRefresh: =>
    if @refreshInterval
      clearInterval(@refreshInterval)
      @refreshInterval = null

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

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


