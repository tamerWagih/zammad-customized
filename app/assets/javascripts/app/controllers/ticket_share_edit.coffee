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
    expiresAt = @share?.expires_at ? ''

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
          <input type="datetime-local" name="expires_at" class="form-control" value="#{expiresAt}">
        </div>
      </div>
    </div>
    """

  submit: (e) =>
    e.preventDefault()
    form_data = @formParam(e.currentTarget)

    # Ensure permissions is always an array
    if form_data.permissions and typeof form_data.permissions is 'string'
      form_data.permissions = [form_data.permissions]

    @ajax(
      id: 'update_share'
      type: 'PATCH'
      url: "#{@apiPath}/tickets/#{@ticket_id}/shares/#{@share.id}"
      data: JSON.stringify(form_data)
      processData: false
      contentType: 'application/json'
      success: @submitSuccess
      error: @submitError
    )

  submitSuccess: (data, status, xhr) =>
    @notify(type: 'success', msg: __('Share updated successfully'))
    @close()
    @callback() if @callback

  submitError: (xhr, status, error) =>
    error_msg = __('Failed to update share')
    try
      response = JSON.parse(xhr.responseText)
      error_msg = response.error if response?.error
    catch
    @notify(type: 'error', msg: error_msg)


