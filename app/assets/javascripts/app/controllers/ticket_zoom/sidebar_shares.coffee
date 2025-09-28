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
    @widget = new App.WidgetShares(
      el:       @elSidebar
      ticket_id: @ticket.id
      parentVC: @
      callback: @refreshShares
    )

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
    
    # Only owner can share and request approval (prevents circular requests)
    if @ticket?.owner_id && String(@ticket.owner_id) == String(current_user.id)
      return true
    
    # TODO: Allow users with edit access to share and request approval later
    # share_permissions = @ticket?.share_permissions
    # if share_permissions && share_permissions.edit
    #   return true
    
    # Everyone else cannot share or request approval
    return false

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')


