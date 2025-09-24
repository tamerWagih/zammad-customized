class SidebarShares extends App.Controller
  sidebarItem: =>
    console.log('SidebarShares sidebarItem called')
    console.log('Current view:', @ticket.currentView())
    console.log('Has ticket.agent permission:', @permissionCheck('ticket.agent'))
    console.log('Has admin permission:', @permissionCheck('admin.*'))
    console.log('Ticket editable:', @ticket.editable())
    console.log('User current:', App.User.current())
    
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

    console.log('SidebarShares item created:', @item)
    console.log('SidebarActions count:', @item.sidebarActions.length)
    console.log('SidebarActions details:', @item.sidebarActions)
    @item

  showPanel: (el) =>
    @elSidebar = el
    console.log('SidebarShares showPanel called', el, @ticket)
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
    console.log('SidebarShares createShare called')
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


