class SidebarShares extends App.Controller
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

    # Only allow sharing if user is not a receiver of this ticket
    unless @isReceiver()
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

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')


