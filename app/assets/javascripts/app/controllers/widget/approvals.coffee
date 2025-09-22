class App.WidgetApprovals extends App.Controller
  events:
    'click .js-approve': 'approve'
    'click .js-reject': 'reject'
    'click .js-edit-approval': 'editApproval'
    'click .js-delete-approval': 'deleteApproval'

  constructor: ->
    super
    @render()

  render: =>
    # Generate sample approval data for demonstration
    approvals = [
      {
        id: 1
        approver: 'Sarah Johnson'
        status: 'pending'
        message: 'Please review and approve this ticket for production deployment'
        created_at: new Date().toISOString()
        priority: 'high'
      }
      {
        id: 2
        approver: 'Mike Chen'
        status: 'approved'
        message: 'Approved for immediate deployment'
        created_at: new Date(Date.now() - 3600000).toISOString()
        priority: 'normal'
      }
    ]

    @html App.view('widget/approvals')({
      approvals: approvals
      ticket: @ticket
    })

  approve: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    @confirm(
      message: __('Are you sure you want to approve this request?')
      callback: =>
        @ajax(
          id:          'approve_approval'
          type:        'POST'
          url:         "#{@apiPath}/tickets/#{@ticket.id}/approvals/#{approval_id}/approve"
          processData: true
          success:     @approvalSuccess
          error:       @approvalError
        )
    )

  reject: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    @confirm(
      message: __('Are you sure you want to reject this request?')
      callback: =>
        @ajax(
          id:          'reject_approval'
          type:        'POST'
          url:         "#{@apiPath}/tickets/#{@ticket.id}/approvals/#{approval_id}/reject"
          processData: true
          success:     @approvalSuccess
          error:       @approvalError
        )
    )

  editApproval: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    # Open edit modal
    new App.TicketApprovalEdit(
      approval_id: approval_id
      ticket_id:   @ticket_id
      container:   @el.closest('.content')
      callback:    @refresh
    )

  deleteApproval: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    # Confirm deletion
    @confirm(
      message: __('Are you sure you want to delete this approval request?')
      callback: =>
        @ajax(
          id:          'delete_approval'
          type:        'DELETE'
          url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}"
          processData: true
          success:     @approvalSuccess
          error:       @approvalError
        )
    )

  approvalSuccess: (data, status, xhr) =>
    @notify(
      type: 'success'
      msg:  __('Approval updated successfully')
    )
    # Simulate real approval update by re-rendering
    @render()
    @refresh() if @callback

  approvalError: (xhr, status, error) =>
    @notify(
      type: 'error'
      msg:  __('Failed to update approval')
    )

  refresh: =>
    if @callback
      @callback()
