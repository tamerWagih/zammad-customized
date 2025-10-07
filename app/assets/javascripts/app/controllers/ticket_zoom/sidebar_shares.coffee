class SidebarShares extends App.Controller
  constructor: ->
    super

  sidebarItem: =>
    # Only show for agent view
    return unless @ticket.currentView() is 'agent'
    
    # Only agents and admins can see shares
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'shares'
      badgeIcon: 'team'
      badgeCallback: @badgeRender
      sidebarHead: __('Shares')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Add action button if user can edit ticket
    if @ticket.editable && @ticket.editable()
      @item.sidebarActions.push(
        title: __('Share Ticket')
        name: 'share-ticket'
        callback: @shareTicket
      )

    @item

  badgeRender: (el) =>
    @badgeEl = el
    @badgeRenderLocal()

  badgeRenderLocal: =>
    return if !@badgeEl
    
    # Count active shares for badge
    shares = @shares || []
    active_count = shares.filter((s) -> s.status is 'active').length
    
    @badgeEl.html(App.view('generic/sidebar_tabs_item')(
      name: 'shares'
      icon: 'group'
      counterPossible: active_count > 0
      counter: active_count
    ))

  reload: (args) =>
    # Standard pattern: update local data if provided (like SidebarTicket)
    if args.shares?
      @shares = args.shares
    
    # Reload widget if it exists
    if @widget && @widget.reload
      @widget.reload(@shares)

  showPanel: (el) =>
    @elSidebar = el
    
    # Standard pattern: create widget and pass data (like SidebarTicket does with WidgetTag)
    @widget = new App.WidgetShares(
      el: @elSidebar
      ticket_id: @ticket.id
      ticket: @ticket
      shares: @shares  # Pass data from parent
    )

  shareTicket: =>
    new App.TicketShareCreate(
      ticket_id: @ticket.id
      container: @el.closest('.content')
      callback: =>
        # Refresh the shares widget after creating
        @widget.reload() if @widget && @widget.reload
    )

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')
