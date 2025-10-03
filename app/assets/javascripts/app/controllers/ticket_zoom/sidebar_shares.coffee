class SidebarShares extends App.Controller
  constructor: ->
    super
    @last_can_share = null

  sidebarItem: =>
    
    return if @ticket.currentView() isnt 'agent'
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'shares'
      badgeIcon: 'team'
      badgeCallback: @badgeRender
      sidebarHead: __('Shares')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Only allow sharing if user is owner or has share access
    if @canShareOrApprove()
      @item.sidebarActions.push(
        title: __('Share Ticket')
        name: 'share-create'
        callback: @createShare
      )

    @item

  showPanel: (el) =>
    @elSidebar = el

    # Ensure ticket object is properly loaded with share permissions
    if @ticket_id
      @ticket = App.Ticket.fullLocal(@ticket_id)
      # If local cache doesn't have share permissions, fetch from server
      if !@ticket?.share_permissions
        @ajax(
          id:    'load_ticket_for_sidebar'
          type:  'GET'
          url:   "#{@apiPath}/tickets/#{@ticket_id}"
          success: (ticketData) =>
            App.Ticket.refresh([ticketData]) if ticketData?
            @ticket = App.Ticket.findNative(@ticket_id)
            @createSharesWidget()
          error: (xhr, status, error) =>
            console.error 'Failed to load ticket for sidebar:', status, error
            @createSharesWidget()
        )
      else
        @createSharesWidget()
    else
      @createSharesWidget()

  createSharesWidget: =>
    # Destroy existing widget if any
    if @widget
      @widget.destroy?()

    @widget = new App.WidgetShares(
      el:       @elSidebar
      ticket_id: @ticket?.id || @ticket_id
      parentVC: @
      callback: @refreshShares
    )
    
    # Ensure widget loads data when panel is shown
    @delay =>
      if @widget
        @widget.reload()
        # Also trigger ensureDataLoaded after a longer delay
        @delay =>
          if @widget && @widget.ensureDataLoaded
            @widget.ensureDataLoaded()
        , 500, 'share-ensure-data'
    , 200, 'share-panel-show'

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
      # Get taskKey from parent controller
      taskKey = @parentVC?.taskKey || @taskKey
      App.Event.trigger('ui::ticket::sidebarRerender', { taskKey: taskKey })

  refreshShares: =>
    if @elSidebar
      @showPanel(@elSidebar)

  createShare: =>
    # Create share modal
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
    # Check if current user can share or request approval
    current_user = App.User.current()
    return false unless current_user
    
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
    
    # Allow owner to share
    if @ticket?.owner_id && String(@ticket.owner_id) == String(current_user.id)
      return true
    
    # Everyone else cannot share or request approval
    return false

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')


