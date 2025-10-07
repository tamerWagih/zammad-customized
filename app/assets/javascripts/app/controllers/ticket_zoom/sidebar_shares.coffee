class SidebarShares extends App.Controller
  constructor: ->
    super
    @last_can_share = null

  sidebarItem: =>
    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: sidebarItem() called"
    
    currentView = @ticket.currentView()
    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: currentView =", currentView
    
    if currentView isnt 'agent'
      console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: Not agent view - hiding sidebar"
      return
    
    # Standard Zammad: Agents and admins can see shares
    # Custom: Also allow users with share access or approval access
    isAgent = @permissionCheck('ticket.agent')
    isAdmin = @permissionCheck('admin.*')
    hasShare = @hasShareAccess()
    hasApproval = @hasApprovalAccess()
    
    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: isAgent =", isAgent, ", isAdmin =", isAdmin, ", hasShare =", hasShare, ", hasApproval =", hasApproval
    
    unless isAgent or isAdmin or hasShare or hasApproval
      console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: No permission - hiding sidebar"
      return

    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: Sidebar WILL be shown"

    @item = {
      name: 'shares'
      badgeIcon: 'team'
      badgeCallback: @badgeRender
      sidebarHead: __('Shares')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    if @canShareOrApprove()
      @item.sidebarActions.push(
        title: __('Share Ticket')
        name: 'share-create'
        callback: @createShare
      )

    @item

  showPanel: (el) =>
    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket_id}: showPanel() called"
    @elSidebar = el

    if @ticket_id
      @ticket = App.Ticket.fullLocal(@ticket_id) || @ticket
      console.log "[SIDEBAR_SHARES] Ticket ##{@ticket_id}: Loaded ticket object:", !!@ticket
      unless @ticket
        console.log "[SIDEBAR_SHARES] Ticket ##{@ticket_id}: No ticket object - loading from API"
        @ajax(
          id:    'load_ticket_for_sidebar'
          type:  'GET'
          url:   "#{@apiPath}/tickets/#{@ticket_id}"
          success: (ticketData) =>
            console.log "[SIDEBAR_SHARES] Ticket ##{@ticket_id}: Ticket loaded from API"
            App.Ticket.refresh([ticketData]) if ticketData?
            @ticket = App.Ticket.findNative(@ticket_id)
            @createSharesWidget()
          error: (xhr, status, error) =>
            console.error "[SIDEBAR_SHARES] Ticket ##{@ticket_id}: Failed to load ticket for sidebar:", status, error unless status is 'abort'
            @createSharesWidget()
        )
        return

    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket_id}: Creating widget"
    @createSharesWidget()

  createSharesWidget: =>
    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: createSharesWidget() called"
    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: elSidebar:", !!@elSidebar
    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: ticket object:", !!@ticket
    
    if @widget
      @widget.destroy?()

    @widget = new App.WidgetShares(
      el:       @elSidebar
      ticket_id: @ticket?.id || @ticket_id
      parentVC: @
      callback: @refreshShares
    )

    console.log "[SIDEBAR_SHARES] Ticket ##{@ticket?.id || @ticket_id}: Widget created:", !!@widget
    
    # Load shares data (use passed data if available)
    @loadSharesForCheck()

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
      , 300, 'update-shares-actions'

  refreshShares: =>
    @showPanel(@elSidebar) if @elSidebar

  loadSharesForCheck: =>
    return unless @ticket

    # Use passed shares data if available, otherwise load from API
    if @shares && @shares.length > 0
      # Data already available from parent controller
      return
    else
      # Fallback: load from API
      @ajax(
        id: 'load_shares_for_check'
        type: 'GET'
        url: "#{@apiPath}/tickets/#{@ticket.id}/shares"
        processData: true
        success: (data, status, xhr) =>
          @shares = data?.shares || []
        error: (xhr, status, error) =>
          @shares = []
      )

  createShare: =>
    new App.TicketShareCreate(
      ticket_id: @ticket.id
      container: @elSidebar.closest('.content')
      callback: @refreshShares
    )

  badgeRender: (el) =>
    @badgeEl = el
    @badgeRenderLocal()

  badgeRenderLocal: =>
    @badgeEl.html(App.view('generic/sidebar_tabs_item')(
      name: 'shares'
      icon: 'team'
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
    
    # Use shares_data attached to ticket object
    ticket_shares = @ticket.shares_data
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
    
    # Use approvals_data attached to ticket object
    ticket_approvals = @ticket.approvals_data
    return false unless ticket_approvals && Array.isArray(ticket_approvals) && ticket_approvals.length > 0
    
    current_user_id = parseInt(current_user.id)
    
    # Check if user is an approver (any status - pending, approved, or rejected)
    for approval in ticket_approvals
      if parseInt(approval.approver_id) is current_user_id
        return true
    
    false

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')
