class App.TicketShareEdit extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Update Share')
  buttonClass: 'btn--primary'
  head: __('Edit Share')

  events:
    'submit form': 'submit'

  content: ->
    groupName = @share?.group_name || @share?.group?.fullname || @share?.group?.name

    """
    <div class="form-horizontal">
      <div class="form-group">
        <label class="control-label col-sm-3">#{__('Group')}</label>
        <div class="col-sm-9">
          <p class="form-control-static">#{groupName || __('Unknown group')}</p>
        </div>
      </div>

      <div class="form-group">
        <label class="control-label col-sm-3">#{__('Message')}</label>
        <div class="col-sm-9">
          <textarea name="message" class="form-control" rows="3">#{@share?.message or ''}</textarea>
        </div>
      </div>
    </div>
    """

  submit: (e) =>
    e.preventDefault()

    unless @share?.id
      @notify(
        type: 'error'
        msg: __('Share data not available. Please close and try again.')
      )
      return

    form_data = @formParam(e.currentTarget)

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
    # Pass the updated share data to callback for immediate local update
    @callback(data.share) if @callback
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
