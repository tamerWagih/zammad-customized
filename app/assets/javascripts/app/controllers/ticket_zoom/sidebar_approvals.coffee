class SidebarApprovals extends App.Controller
  constructor: ->
    super
    @last_can_share = null
    
    # Set cache on ticket object for permission checks (same pattern as standard Zammad uses for tags/links)
    if @ticket && @approvals
      @ticket._approvals_cache = @approvals
    if @ticket && @shares
      @ticket._shares_cache = @shares

  sidebarItem: =>
    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: sidebarItem() called"
    
    currentView = @ticket.currentView()
    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: currentView =", currentView
    
    if currentView isnt 'agent'
      console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: Not agent view - hiding sidebar"
      return
    
    # Standard Zammad: Agents and admins can see approvals
    # Custom: Also allow users with share access or approval access
    isAgent = @permissionCheck('ticket.agent')
    isAdmin = @permissionCheck('admin.*')
    hasShare = @hasShareAccess()
    hasApproval = @hasApprovalAccess()
    
    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: isAgent =", isAgent, ", isAdmin =", isAdmin, ", hasShare =", hasShare, ", hasApproval =", hasApproval
    
    unless isAgent or isAdmin or hasShare or hasApproval
      console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: No permission - hiding sidebar"
      return

    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: Sidebar WILL be shown"

    @item = {
      name: 'approvals'
      badgeIcon: 'checkmark'
      badgeCallback: @badgeRender
      sidebarHead: __('Approvals')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    if @canShareOrApprove()
      @item.sidebarActions.push(
        title: __('Request Approval')
        name: 'approval-request'
        callback: @requestApproval
      )

    @item

  showPanel: (el) =>
    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket_id}: showPanel() called"
    @elSidebar = el

    if @ticket_id
      @ticket = App.Ticket.fullLocal(@ticket_id) || @ticket
      console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket_id}: Loaded ticket object:", !!@ticket
      unless @ticket
        console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket_id}: No ticket object - loading from API"
        @ajax(
          id:    'load_ticket_for_sidebar'
          type:  'GET'
          url:   "#{@apiPath}/tickets/#{@ticket_id}"
          success: (ticketData) =>
            console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket_id}: Ticket loaded from API"
            App.Ticket.refresh([ticketData]) if ticketData?
            @ticket = App.Ticket.findNative(@ticket_id)
            @createApprovalsWidget()
          error: (xhr, status, error) =>
            console.error "[SIDEBAR_APPROVALS] Ticket ##{@ticket_id}: Failed to load ticket for sidebar:", status, error unless status is 'abort'
            @createApprovalsWidget()
        )
        return

    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket_id}: Creating widget"
    @createApprovalsWidget()

  createApprovalsWidget: =>
    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: createApprovalsWidget() called"
    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: elSidebar:", !!@elSidebar
    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: ticket object:", !!@ticket
    
    @widget?.destroy?()

    @widget = new App.WidgetApprovals(
      el:       @elSidebar
      ticket_id: @ticket?.id || @ticket_id
      parentVC: @
      callback: @refreshApprovals
    )

    console.log "[SIDEBAR_APPROVALS] Ticket ##{@ticket?.id || @ticket_id}: Widget created:", !!@widget

    # Load approvals data (use passed data if available)
    @loadApprovalsForCheck()

  reload: (args) =>
    if @widget && @widget.reload
      @widget.reload(args)
    else if @elSidebar
      @showPanel(@elSidebar)

    @checkAndUpdateActions()

  checkAndUpdateActions: =>
    current_can_share = @canShareOrApprove()
    if @last_can_share isnt current_can_share
      @last_can_share = current_can_share
      @delay =>
        taskKey = @parentVC?.taskKey || @taskKey
        if taskKey
          App.Event.trigger('ui::ticket::sidebarRerender', { taskKey: taskKey, ticket_id: @ticket?.id || @ticket_id })
      , 300, 'update-approvals-actions'

  refreshApprovals: =>
    @showPanel(@elSidebar) if @elSidebar

  loadApprovalsForCheck: =>
    return unless @ticket

    # Use passed approvals data if available, otherwise load from API
    if @approvals && @approvals.length > 0
      # Data already available from parent controller
      return
    else
      # Fallback: load from API
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
    current_user = App.User.current()
    return false unless current_user
    
    # Admins and agents can always share/approve
    return true if @permissionCheck('admin.*') or @permissionCheck('ticket.agent')
    
    # Check if user is accessing via shares (receivers cannot share/approve)
    return false if @hasShareAccess()
    
    # User is the ticket owner or in the ticket's group
    true

  hasShareAccess: =>
    return false unless @ticket
    current_user = App.User.current()
    return false unless current_user

    # Use shares passed from constructor/reload
    ticket_shares = @shares || []
    return false unless ticket_shares && Array.isArray(ticket_shares) && ticket_shares.length > 0

    # Filter only active shares
    active_shares = ticket_shares.filter((share) -> share.status is 'active')
    return false unless active_shares.length > 0

    # Get user's groups
    user_groups = current_user.group_ids || []
    share_groups = active_shares.map((share) -> parseInt(share.group_id))

    # Check if user belongs to any shared group
    for user_group_id in user_groups
      if share_groups.indexOf(parseInt(user_group_id)) >= 0
        return true

    false

  hasApprovalAccess: =>
    return false unless @ticket
    current_user = App.User.current()
    return false unless current_user

    # Use approvals passed from constructor/reload
    ticket_approvals = @approvals || []
    return false unless ticket_approvals && Array.isArray(ticket_approvals) && ticket_approvals.length > 0

    current_user_id = parseInt(current_user.id)

    # Check if user is an approver (any status - pending, approved, or rejected)
    for approval in ticket_approvals
      if parseInt(approval.approver_id) is current_user_id
        return true

    false

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')
