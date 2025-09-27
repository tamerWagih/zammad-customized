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
    # Check if current user is a receiver of a share or approval for this ticket
    current_user = App.User.current()
    return false unless current_user
    
    # Method 1: Check if user has share permissions (indicating they are a receiver)
    share_permissions = @ticket?.share_permissions
    if share_permissions && (share_permissions.read || share_permissions.comment || share_permissions.edit)
      return true
    
    # Method 2: Check if user is the ticket owner (owners can always share)
    if @ticket?.owner_id && String(@ticket.owner_id) == String(current_user.id)
      return false
    
    # Method 3: Check if user is in the same organization as owner (agents/admins can share)
    if @ticket?.organization_id && current_user.organization_id && 
       String(@ticket.organization_id) == String(current_user.organization_id)
      return false
    
    # Method 4: Check if user has ticket.agent permission (agents can share)
    if current_user.permissions && current_user.permissions.indexOf('ticket.agent') >= 0
      return false
    
    # If none of the above, they might be a receiver
    return true

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')


