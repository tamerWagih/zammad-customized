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
    # Render approvals list with interactive elements
    @html $(App.view('widget/approvals')({
      approvals: @approvals
      ticket_id: @ticket_id
    }))

  approve: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    @ajax(
      id:          'approve_approval'
      type:        'POST'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}/approve"
      processData: true
      success:     @approvalSuccess
      error:       @approvalError
    )

  reject: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    @ajax(
      id:          'reject_approval'
      type:        'POST'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}/reject"
      processData: true
      success:     @approvalSuccess
      error:       @approvalError
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
    @refresh() if @callback

  approvalError: (xhr, status, error) =>
    @notify(
      type: 'error'
      msg:  __('Failed to update approval')
    )

  refresh: =>
    if @callback
      @callback()
