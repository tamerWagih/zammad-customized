class SidebarApprovals extends App.Controller
  constructor: (params) ->
    super
    
    # Store approvals from parent (same pattern as SidebarTicket with tags/links)
    @approvals = params.approvals || []

  sidebarItem: =>
    # Only show for agent view
    return unless @ticket.currentView() is 'agent'
    
    # Only agents and admins can see approvals
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'approvals'
      badgeIcon: 'checkmark'
      badgeCallback: @badgeRender
      sidebarHead: __('Approvals')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Add action button if user can edit ticket
    if @ticket.editable && @ticket.editable()
      @item.sidebarActions.push(
        title: __('Request Approval')
        name: 'approval-request'
        callback: @requestApproval
      )

    @item

  badgeRender: (el) =>
    @badgeEl = el
    @badgeRenderLocal()

  badgeRenderLocal: =>
    return if !@badgeEl
    
    # Count pending approvals for badge
    approvals = @approvals || []
    pending_count = approvals.filter((a) -> a.status is 'pending').length
    
    @badgeEl.html(App.view('generic/sidebar_tabs_item')(
      name: 'approvals'
      icon: 'checkmark'
      counterPossible: pending_count > 0
      counter: pending_count
    ))

  reload: (args) =>
    # Standard pattern: update local data if provided (like SidebarTicket)
    if args.approvals?
      @approvals = args.approvals
    
    # Reload widget if it exists
    if @widget && @widget.reload
      @widget.reload(@approvals)

  showPanel: (el) =>
    @elSidebar = el
    
    # Standard pattern: create widget and pass data (like SidebarTicket does with WidgetTag)
    @widget = new App.WidgetApprovals(
      el: @elSidebar
      ticket_id: @ticket.id
      ticket: @ticket
      approvals: @approvals  # Pass data from parent
    )

  requestApproval: =>
    new App.TicketApprovalRequest(
      ticket_id: @ticket.id
      container: @el.closest('.content')
      callback: =>
        # Refresh the approvals widget by fetching fresh data from API
        @widget.fetch() if @widget && @widget.fetch
    )

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')
