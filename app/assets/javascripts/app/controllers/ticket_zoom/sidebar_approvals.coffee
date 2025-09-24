class SidebarApprovals extends App.Controller
  sidebarItem: =>
    console.log('SidebarApprovals sidebarItem called')
    console.log('Current view:', @ticket.currentView())
    console.log('Has ticket.agent permission:', @permissionCheck('ticket.agent'))
    console.log('Has admin permission:', @permissionCheck('admin.*'))
    console.log('Ticket editable:', @ticket.editable())
    console.log('User current:', App.User.current())
    
    return if @ticket.currentView() isnt 'agent'
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'approvals'
      badgeIcon: 'checkmark'
      badgeCallback: @badgeRender
      sidebarHead: __('Approvals')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Add action to create new approval request
    @item.sidebarActions.push
      title: __('Request Approval')
      name: 'approval-request'
      callback: @requestApproval

    console.log('SidebarApprovals item created:', @item)
    console.log('SidebarActions count:', @item.sidebarActions.length)
    console.log('SidebarActions details:', @item.sidebarActions)
    @item

  showPanel: (el) =>
    @elSidebar = el
    console.log('SidebarApprovals showPanel called', el, @ticket)
    @widget = new App.WidgetApprovals(
      el:       @elSidebar
      ticket_id: @ticket.id
      parentVC: @
      callback: @refreshApprovals
    )

  refreshApprovals: =>
    if @elSidebar
      @showPanel(@elSidebar)

  requestApproval: =>
    console.log('SidebarApprovals requestApproval called')
    # Create approval request modal
    new App.TicketApprovalRequest(
      ticket_id: @ticket.id
      container: @elSidebar.closest('.content')
      callback:  @refreshApprovals
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

App.Config.set('450-Approvals', SidebarApprovals, 'TicketZoomSidebar')


