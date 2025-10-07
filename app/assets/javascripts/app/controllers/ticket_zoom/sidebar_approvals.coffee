class SidebarApprovals extends App.Controller
  constructor: ->
    super

  sidebarItem: =>
    # Only show for agent view
    return unless @ticket.currentView() is 'agent'
    
    # Only agents and admins can see approvals
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'approvals'
      badgeIcon: 'checkmark'
      badgeCallback: @badgeRender
      sidebarHead: __('Approvals')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Add action button if user can edit ticket
    if @ticket.editable && @ticket.editable()
      @item.sidebarActions.push(
        title: __('Request Approval')
        name: 'approval-request'
        callback: @requestApproval
      )

    @item

  badgeRender: (el) =>
    # Count pending approvals for badge
    approvals = @approvals || []
    pending_count = approvals.filter((a) -> a.status is 'pending').length
    
    if pending_count > 0
      el.html(App.view('generic/badge')(
        text: pending_count
        type: 'warning'
      ))

  reload: (args) =>
    # Standard pattern: update local data if provided (like SidebarTicket)
    if args.approvals?
      @approvals = args.approvals
    
    # Reload widget if it exists
    if @widget && @widget.reload
      @widget.reload(@approvals)

  showPanel: (el) =>
    @elSidebar = el
    
    # Standard pattern: create widget and pass data (like SidebarTicket does with WidgetTag)
    @widget = new App.WidgetApprovals(
      el: @elSidebar
      ticket_id: @ticket.id
      ticket: @ticket
      approvals: @approvals  # Pass data from parent
    )

  requestApproval: =>
    new ApprovalRequest(
      ticket_id: @ticket.id
      container: @el.closest('.content')
    )

class ApprovalRequest extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Request Approval')
  head: __('Request Approval')

  content: =>
    @ticket = App.Ticket.find(@ticket_id)
    
    content = $( App.view('widget/approval_request')(
      ticket: @ticket
    ))
    
    # Initialize user search for approver selection
    content.find('.js-approver').each( (i, el) =>
      @userSearchElement = new App.UserSearch(
        el: $(el)
      )
    )
    
    content

  onSubmit: (e) =>
    e.preventDefault()
    params = @formParam(e.target)
    
    unless params.approver_id
      @formValidate(form: e.target, errors: { approver_id: 'required' })
      return
    
    @ajax(
      id:   'create_approval'
      type: 'POST'
      url:  "#{@apiPath}/tickets/#{@ticket_id}/approvals"
      data: JSON.stringify(params)
      processData: false
      success: =>
        @close()
      error: (xhr, status, error) =>
        console.error 'Failed to create approval:', status, error
        @notify(
          type: 'error'
          msg: App.i18n.translateContent('Failed to create approval request.')
        )
    )

App.Config.set('500-Approvals', SidebarApprovals, 'TicketZoomSidebar')
