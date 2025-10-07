class App.WidgetApprovals extends App.Controller
  events:
    'click .js-approve': 'approve'
    'click .js-reject': 'reject'
    'click .js-edit-approval': 'editApproval'
    'click .js-delete-approval': 'deleteApproval'
    'click .js-request-approval': 'openRequestApproval'

  constructor: ->
    super
    
    # Standard pattern: if approvals passed from parent, use them (like WidgetTag)
    if @approvals
      @localApprovals = _.clone(@approvals)
      @render()
      return
    
    # Fallback: fetch from API if not provided
    @fetch()

  fetch: =>
    return unless @ticket_id
    
    @ajax(
      id:          'load_approvals'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals"
      processData: true
      success:     (data) =>
        @localApprovals = data?.approvals || []
        @render()
      error: (xhr, status, error) =>
        console.error 'Failed to load approvals:', status, error
        @localApprovals = []
        @render()
    )

  reload: (approvals) =>
    # Standard pattern: just update local data and re-render (like WidgetTag)
    @localApprovals = _.clone(approvals)
    @render()

  render: =>
    # Prevent unnecessary re-renders (like WidgetTag)
    return if @lastLocalApprovals && _.isEqual(@lastLocalApprovals, @localApprovals)
    @lastLocalApprovals = _.clone(@localApprovals)
    
    current_user = App.User.current()
    approvals_data = @localApprovals || []
    
    # Refresh ticket for permission checks
    if @ticket_id
      @ticket = App.Ticket.findNative(@ticket_id) || App.Ticket.fullLocal(@ticket_id)
    
    # Check if current user can manage approvals
    can_manage = @ticket && @ticket.editable && @ticket.editable()
    
    # Prepare display data
    for approval in approvals_data
      approval.can_approve = current_user && parseInt(approval.approver_id) is parseInt(current_user.id) && approval.status is 'pending'
      approval.can_manage = can_manage
      approval.is_pending = approval.status is 'pending'
      approval.is_approved = approval.status is 'approved'
      approval.is_rejected = approval.status is 'rejected'
      
      # Get user names properly (handle both object and string formats)
      if approval.approver
        if typeof approval.approver is 'object'
          approval.approver_name = approval.approver_name || approval.approver.firstname + ' ' + approval.approver.lastname
        else
          approval.approver_name = approval.approver
      
      if approval.requester
        if typeof approval.requester is 'object'
          approval.requester_name = approval.requester_name || approval.requester.firstname + ' ' + approval.requester.lastname
        else
          approval.requester_name = approval.requester
      
      # Format dates (use App.i18n for timestamp formatting)
      if approval.created_at
        approval.created_at_formatted = App.i18n.translateTimestamp(approval.created_at)
      if approval.updated_at
        approval.updated_at_formatted = App.i18n.translateTimestamp(approval.updated_at)
    
    @html App.view('widget/approvals')(
      approvals: approvals_data
      ticket_id: @ticket_id
      current_user_id: current_user.id
    )

  approve: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('id')
    return unless approval_id
    
    new App.ControllerConfirm(
      message: __('Are you sure you want to approve this request?')
      callback: =>
        @updateApprovalStatus(approval_id, 'approved')
      container: @el.closest('.content')
    )

  reject: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('id')
    return unless approval_id
    
    new App.ControllerConfirm(
      message: __('Are you sure you want to reject this request?')
      callback: =>
        @updateApprovalStatus(approval_id, 'rejected')
      container: @el.closest('.content')
    )

  updateApprovalStatus: (approval_id, status) =>
    @ajax(
      id:   'update_approval'
      type: 'PUT'
      url:  "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}"
      data: JSON.stringify(status: status)
      processData: false
      success: =>
        # Backend will trigger WebSocket event, which will refresh the data
        # No need to manually reload here
      error: (xhr, status, error) =>
        console.error 'Failed to update approval:', status, error
        @notify(
          type: 'error'
          msg: App.i18n.translateContent('Failed to update approval status.')
        )
    )

  editApproval: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('id')
    return unless approval_id
    
    # Find the approval in local data
    approval = _.find(@localApprovals, (a) -> parseInt(a.id) is parseInt(approval_id))
    return unless approval
    
    new ApprovalEdit(
      ticket_id: @ticket_id
      approval: approval
      container: @el.closest('.content')
    )

  deleteApproval: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('id')
    return unless approval_id
    
    new App.ControllerConfirm(
      message: __('Are you sure you want to delete this approval request?')
      callback: =>
        @ajax(
          id:   'delete_approval'
          type: 'DELETE'
          url:  "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}"
          success: =>
            # Backend will trigger WebSocket event, which will refresh the data
          error: (xhr, status, error) =>
            console.error 'Failed to delete approval:', status, error
            @notify(
              type: 'error'
              msg: App.i18n.translateContent('Failed to delete approval.')
            )
        )
      container: @el.closest('.content')
    )

  openRequestApproval: (e) =>
    e.preventDefault()
    new ApprovalRequest(
      ticket_id: @ticket_id
      container: @el.closest('.content')
    )

class ApprovalRequest extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Request Approval')
  head: __('Request Approval')

  content: =>
    @ticket = App.Ticket.find(@ticket_id)
    
    # Get all agents for approver selection
    agents = []
    for user_id, user of App.User.all()
      if user.active && user.permissions?('ticket.agent')
        agents.push(user)
    
    # Sort by name
    agents = _.sortBy(agents, (agent) -> agent.displayName())
    
    content = $( App.view('widget/approval_request')(
      ticket: @ticket
      agents: agents
    ))
    
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
        # Backend will trigger WebSocket event, which will refresh the data
      error: (xhr, status, error) =>
        console.error 'Failed to create approval:', status, error
        @notify(
          type: 'error'
          msg: App.i18n.translateContent('Failed to create approval request.')
        )
    )

class ApprovalEdit extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Update')
  head: __('Edit Approval')

  content: =>
    @ticket = App.Ticket.find(@ticket_id)
    
    # Get all agents for approver selection
    agents = []
    for user_id, user of App.User.all()
      if user.active && user.permissions?('ticket.agent')
        agents.push(user)
    
    # Sort by name
    agents = _.sortBy(agents, (agent) -> agent.displayName())
    
    content = $( App.view('widget/approval_edit')(
      ticket: @ticket
      approval: @approval
      agents: agents
    ))
    
    content

  onSubmit: (e) =>
    e.preventDefault()
    params = @formParam(e.target)
    
    unless params.approver_id
      @formValidate(form: e.target, errors: { approver_id: 'required' })
      return
    
    @ajax(
      id:   'update_approval'
      type: 'PUT'
      url:  "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{@approval.id}"
      data: JSON.stringify(params)
      processData: false
      success: =>
        @close()
        # Backend will trigger WebSocket event, which will refresh the data
      error: (xhr, status, error) =>
        console.error 'Failed to update approval:', status, error
        @notify(
          type: 'error'
          msg: App.i18n.translateContent('Failed to update approval.')
        )
    )
