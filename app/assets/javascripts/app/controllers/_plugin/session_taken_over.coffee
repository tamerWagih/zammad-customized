class SessionTakeOver extends App.Controller
  constructor: ->
    super

    @controllerBind(
      'ws:login'
      ->
        App.WebSocket.send(
          event: 'session_takeover',
          data:
            taskbar_id: App.TaskManager.TaskbarId()
        )
    )

    # session take over message - DISABLED for multi-tab support
    # Multiple browser tabs are now allowed for the same user session
    @controllerBind(
      'session_takeover'
      (data) =>
        # Multi-tab support: Allow multiple tabs per session
        # Do NOT disconnect other tabs when a new tab opens
        return
    )


App.Config.set('session_taken_over', SessionTakeOver, 'Plugins')
