class App.WidgetApprovals extends App.Controller
  events:
    'click .js-approve': 'approve'
    'click .js-reject': 'reject'
    'click .js-edit-approval': 'editApproval'
    'click .js-delete-approval': 'deleteApproval'
    'click .js-request-approval': 'openRequestApproval'

  constructor: ->
    super
    @loadRetryCount = 0
    @loadApprovals()
    @renderActions()
    
    # Listen for ticket updates to refresh approvals
    @controllerBind('Ticket:update Ticket:touch', (data) =>
      return if data.id.toString() isnt @ticket_id.toString()
      @delay =>
        @loadApprovals()
      , 500, 'approval-reload'
    )
    
    # Custom approval events removed - using standard Ticket:update events instead
    
    # Listen for notification events to refresh approvals
    @controllerBind('OnlineNotification::changed', =>
      @delay =>
        @loadApprovals()
      , 800, 'approval-reload-notify'
    )
    
    # Listen for real-time updates from other users with debounce
    @controllerBind('TicketApproval:create', (data) =>
      @delay =>
        @loadApprovals()
      , 500, 'approval-reload'
    )
    @controllerBind('TicketApproval:update', (data) =>
      @delay =>
        @loadApprovals()
      , 500, 'approval-reload'
    )
    @controllerBind('TicketApproval:destroy', (data) =>
      @delay =>
        @loadApprovals()
      , 500, 'approval-reload'
    )

  # Standard reload method called by sidebar system
  reload: (args) =>
    @loadApprovals()

  loadApprovals: =>
    return if @isLoadingApprovals
    
    @isLoadingApprovals = true
    @ajax(
      id:          'load_approvals'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals"
      processData: true
      success:     @renderApprovals
      error:       @renderError
      complete:    (xhr, status) =>
        @isLoadingApprovals = false
        if status is 'abort'
          if (@loadRetryCount ? 0) < 3
            @loadRetryCount = (@loadRetryCount ? 0) + 1
            @delay (=> @loadApprovals()), 200, 'approval-retry'
    )

  renderApprovals: (data, status, xhr) =>
    @approvals = data?.approvals || []
    @loadRetryCount = 0
    @render(@approvals)

  renderError: (xhr, status, error) =>
    # Ignore aborted requests caused by view re-renders/navigation
    if status is 'abort' or error is 'abort'
      return
    
    error_message = 'Unable to load approvals'
    if xhr?.responseJSON?.error
      error_message = xhr.responseJSON.error
    else if xhr?.statusText
      error_message = "Unable to load approvals: #{xhr.statusText}"
    
    @html "<div class='sidebar-block'><div class='alert alert-danger'>#{error_message}</div></div>"

  render: (approvals) =>
    # Render the full template with real data
    current_user = App.User.current()
    current_user_id = if current_user then String(current_user.id) else 'unknown'
    
    @html App.view('widget/approvals')(
      approvals: approvals
      ticket_id: @ticket_id
      current_user_id: current_user_id
    )

  renderActions: =>
    @parentVC?.parentSidebar?.sidebarActionsRender('approvals', @parentVC?.item?.sidebarActions || [])

  openRequestApproval: (e) =>
    e?.preventDefault()
    new App.TicketApprovalRequest(
      ticket_id: @ticket_id
      container: @el.closest('.content')
      callback:  => @loadApprovals()
    )


  approve: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    @setCurrentAction('approve')
    
    @ajax(
      id: 'approve_approval'
      type: 'POST'
      url: "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}/approve"
      processData: true
      success: @approvalSuccess
      error: @approvalError
    )

  reject: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    @setCurrentAction('reject')
    
    @ajax(
      id: 'reject_approval'
      type: 'POST'
      url: "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}/reject"
      processData: true
      success: @approvalSuccess
      error: @approvalError
    )

  editApproval: (e) =>
    e.preventDefault()
    e.stopPropagation()
    e.stopImmediatePropagation()
    @setCurrentAction('edit')
    
    approval_id = $(e.currentTarget).data('approval-id')
    
    # Find the approval data
    approval = @approvals?.find (a) -> a.id.toString() == approval_id.toString()
    if approval
      # Create edit modal with current data
      new App.TicketApprovalEdit(
        approval: approval
        ticket_id: @ticket_id
        container: @el.closest('.content')
        callback: => 
          @loadApprovals()
        parentWidget: @
      )

  deleteApproval: (e) =>
    e.preventDefault()
    e.stopPropagation()
    e.stopImmediatePropagation()
    
    approval_id = $(e.currentTarget).data('approval-id')
    
    # Prevent multiple modals
    return if @__deleteModalOpen
    @__deleteModalOpen = true
    
    # Simple confirmation modal like translation controller
    new App.ControllerConfirm(
      message: __('Are you sure you want to delete this approval request? This action cannot be undone.'),
      buttonClass: 'btn--danger',
      callback: =>
        @setCurrentAction('delete')
        @ajax(
          id: 'delete_approval'
          type: 'DELETE'
          url: "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}"
          processData: true
          success: @approvalSuccess
          error: @approvalError
        )
      buttonCancel: true
      container: @el.closest('.content')
    )
    
    # Reset flag after modal is created
    @delay =>
      @__deleteModalOpen = false
    , 100

  approvalSuccess: (data, status, xhr) =>
    # Get the action type from the AJAX request to show appropriate message
    action = @getCurrentAction()
    if action is 'approve'
      @notify(type: 'success', msg: __('Approval request approved successfully'))
    else if action is 'reject'
      @notify(type: 'success', msg: __('Approval request rejected successfully'))
    else if action is 'delete'
      @notify(type: 'success', msg: __('Approval request deleted successfully'))
    else if action is 'edit'
      @notify(type: 'success', msg: __('Approval request updated successfully'))
    # Don't show generic success message for edit actions to avoid duplicates
    
    # Reload approvals from backend immediately
    @loadApprovals()
    @callback() if @callback
    @clearCurrentAction()

  approvalError: (xhr, status, error) =>
    action = @getCurrentAction()
    if action is 'approve'
      @notify(type: 'error', msg: __('Failed to approve request'))
    else if action is 'reject'
      @notify(type: 'error', msg: __('Failed to reject request'))
    else if action is 'delete'
      @notify(type: 'error', msg: __('Failed to delete approval request'))
    else
      @notify(type: 'error', msg: __('Failed to update approval'))
    @clearCurrentAction()

  getCurrentAction: =>
    @currentAction

  setCurrentAction: (action) =>
    @currentAction = action

  clearCurrentAction: =>
    @currentAction = null


  refresh: =>
    if @callback
      @callback()

  reload: =>
    @loadApprovals()
