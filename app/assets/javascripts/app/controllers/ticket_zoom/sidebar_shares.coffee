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

    # Add action to create new share
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

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')


