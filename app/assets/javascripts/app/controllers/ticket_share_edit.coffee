class App.TicketShareEdit extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Update Share')
  buttonClass: 'btn--primary'
  head: __('Edit Share')

  events:
    'submit form': 'submit'

  # Rely on App.ControllerModal to assign passed options directly

  content: ->
    permissions = @share?.permissions or []
    hasEdit = permissions?.indexOf('edit') >= 0
    hasRead = permissions?.indexOf('read') >= 0
    
    # Determine current access level
    currentAccessLevel = if hasEdit then 'full' else 'read'
    
    # Normalize expires_at to datetime-local value (YYYY-MM-DDTHH:MM)
    expiresAt = ''
    if @share?.expires_at
      try
        dt = new Date(@share.expires_at)
        # Pad to 2 digits
        pad = (n) -> ("0" + n).slice(-2)
        y = dt.getFullYear()
        m = pad(dt.getMonth()+1)
        d = pad(dt.getDate())
        h = pad(dt.getHours())
        min = pad(dt.getMinutes())
        expiresAt = "#{y}-#{m}-#{d}T#{h}:#{min}"
      catch
        # Try to extract datetime part from string if it's in datetime format
        if @share.expires_at.match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/)
          expiresAt = @share.expires_at.match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/)[0]
        else if @share.expires_at.match(/^\d{4}-\d{2}-\d{2}/)
          expiresAt = @share.expires_at.match(/^\d{4}-\d{2}-\d{2}/)[0] + "T00:00"
        else
          expiresAt = @share.expires_at

    """
    <div class="form-horizontal">
      <div class="form-group">
        <label class="control-label col-sm-3">#{__('Access Level')}</label>
        <div class="col-sm-9">
          <div class="radio">
            <label>
              <input type="radio" name="access_level" value="full" #{if currentAccessLevel is 'full' then 'checked' else ''}>
              <strong>#{__('Full Access')}</strong>
              <br><small class="text-muted">#{__('View, comment, and edit ticket')}</small>
            </label>
          </div>
          <div class="radio">
            <label>
              <input type="radio" name="access_level" value="read" #{if currentAccessLevel is 'read' then 'checked' else ''}>
              <strong>#{__('Read Only')}</strong>
              <br><small class="text-muted">#{__('View ticket and comments only')}</small>
            </label>
          </div>
        </div>
      </div>

      <div class="form-group">
        <label class="control-label col-sm-3">#{__('Message')}</label>
        <div class="col-sm-9">
          <textarea name="message" class="form-control" rows="3">#{@share?.message or ''}</textarea>
        </div>
      </div>

      <div class="form-group">
        <label class="control-label col-sm-3">#{__('Expires At (Optional)')}</label>
        <div class="col-sm-9">
          <input type="datetime-local" name="expires_at" class="form-control" value="#{expiresAt}" min="#{new Date().toISOString().slice(0, 16)}">
          <small class="help-block">#{__('Leave empty for no expiration')}</small>
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
    
    # Convert access_level to permissions array
    access_level = form_data.access_level || 'full'
    if access_level is 'full'
      form_data.permissions = ['read', 'comment', 'edit']
    else if access_level is 'read'
      form_data.permissions = ['read']
    
    # Remove access_level from form data as backend expects permissions array
    delete form_data.access_level
    
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
    # Don't show notification here to avoid double messages
    # The parent widget will handle the success notification
    
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


