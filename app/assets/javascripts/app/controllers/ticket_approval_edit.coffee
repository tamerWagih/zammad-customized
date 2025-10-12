class App.TicketApprovalEdit extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Update Approval Request')
  buttonClass: 'btn--primary'
  head: __('Edit Approval Request')
  
  events:
    'submit form': 'submit'
  # Rely on App.ControllerModal to assign passed options directly

  content: ->
    # Return simple edit form
    """
    <div class="form-horizontal">
      <div class="form-group">
        <label class="control-label col-sm-3">
          #{__('Message')}
        </label>
        <div class="col-sm-9">
          <textarea name="message" class="form-control" rows="4" placeholder="#{__('Optional message for the approver...')}">#{@approval?.message || ''}</textarea>
        </div>
      </div>

      <div class="form-group">
        <label class="control-label col-sm-3">
          #{__('Priority')}
        </label>
        <div class="col-sm-9">
          <select name="priority" class="form-control">
            <option value="low" #{if @approval?.priority is 'low' then 'selected' else ''}>
              #{__('Low')}
            </option>
            <option value="normal" #{if @approval?.priority is 'normal' or !@approval?.priority then 'selected' else ''}>
              #{__('Normal')}
            </option>
            <option value="high" #{if @approval?.priority is 'high' then 'selected' else ''}>
              #{__('High')}
            </option>
            <option value="urgent" #{if @approval?.priority is 'urgent' then 'selected' else ''}>
              #{__('Urgent')}
            </option>
          </select>
        </div>
      </div>
    </div>
    """

  submit: (e) =>
    e.preventDefault()
    
    form_data = @formParam(e.currentTarget)
    
    # Send flat form data like create method does
    @ajax(
      id: 'update_approval_request'
      type: 'PATCH'
      url: "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{@approval.id}"
      data: form_data
      processData: true
      contentType: 'application/x-www-form-urlencoded; charset=UTF-8'
      success: @submitSuccess
      error: @submitError
    )

  submitSuccess: (data, status, xhr) =>
    # Pass the updated approval data to callback for immediate local update
    @callback(data.approval) if @callback
    @close()

  submitError: (xhr, status, error) =>
    error_msg = __('Failed to update approval request')
    try
      response = JSON.parse(xhr.responseText)
      error_msg = response.error if response?.error
    catch
      error_msg = xhr.responseText || error_msg
    
    @notify(
      type: 'error'
      msg: error_msg
    )
