class App.TicketShareEdit extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Update Share')
  buttonClass: 'btn--primary'
  head: __('Edit Share')

  events:
    'submit form': 'submit'

  content: ->
    permissions = @share?.permissions or []
    checked = (name) -> if permissions?.indexOf(name) >= 0 then 'checked' else ''
    # Normalize expires_at to date value (YYYY-MM-DD)
    expiresAt = ''
    if @share?.expires_at
      try
        dt = new Date(@share.expires_at)
        # Pad to 2 digits
        pad = (n) -> ("0" + n).slice(-2)
        y = dt.getFullYear()
        m = pad(dt.getMonth()+1)
        d = pad(dt.getDate())
        expiresAt = "#{y}-#{m}-#{d}"
      catch
        # Try to extract date part from string if it's in datetime format
        if @share.expires_at.match(/^\d{4}-\d{2}-\d{2}/)
          expiresAt = @share.expires_at.match(/^\d{4}-\d{2}-\d{2}/)[0]
        else
          expiresAt = @share.expires_at

    """
    <div class="form-horizontal">
      <div class="form-group">
        <label class="control-label col-sm-3">#{__('Permissions')}</label>
        <div class="col-sm-9">
          <label class="checkbox-inline">
            <input type="checkbox" name="permissions[]" value="read" #{checked('read')}> #{__('Read')}
          </label>
          <label class="checkbox-inline">
            <input type="checkbox" name="permissions[]" value="comment" #{checked('comment')}> #{__('Comment')}
          </label>
          <label class="checkbox-inline">
            <input type="checkbox" name="permissions[]" value="edit" #{checked('edit')}> #{__('Edit')}
          </label>
        </div>
      </div>

      <div class="form-group">
        <label class="control-label col-sm-3">#{__('Message')}</label>
        <div class="col-sm-9">
          <textarea name="message" class="form-control" rows="3">#{@share?.message or ''}</textarea>
        </div>
      </div>

      <div class="form-group">
        <label class="control-label col-sm-3">#{__('Expires at')}</label>
        <div class="col-sm-9">
          <input type="date" name="expires_at" class="form-control" value="#{expiresAt}">
        </div>
      </div>
    </div>
    """

  submit: (e) =>
    e.preventDefault()
    
    # Safety check - ensure we have share data
    unless @share?.id
      @notify(
        type: 'error'
        msg: __('Share data not available. Please close and try again.')
      )
      return
    
    form_data = @formParam(e.currentTarget)
    
    # Send flat form data like approval edit does
    @ajax(
      id: 'update_share'
      type: 'PATCH'
      url: "#{@apiPath}/tickets/#{@ticket_id}/shares/#{@share.id}"
      data: form_data
      processData: true
      contentType: 'application/x-www-form-urlencoded; charset=UTF-8'
      success: @submitSuccess
      error: @submitError
    )

  submitSuccess: (data, status, xhr) =>
    @notify(
      type: 'success'
      msg:  __('Share updated successfully')
    )
    
    # Trigger the same success pattern as approval edit for immediate updates
    App.Event.trigger('Ticket:update', { id: @ticket_id })
    
    # Call parent widget's success handler for immediate update
    if @parentWidget && @parentWidget.shareSuccess
      @parentWidget.shareSuccess(data, status, xhr)
    else
      # Fallback to callback
      @callback() if @callback
    
    @close()

  submitError: (xhr, status, error) =>
    error_msg = __('Failed to update share')
    try
      response = JSON.parse(xhr.responseText)
      error_msg = response.error if response?.error
    catch
      error_msg = xhr.responseText || error_msg
    
    @notify(
      type: 'error'
      msg: error_msg
    )


