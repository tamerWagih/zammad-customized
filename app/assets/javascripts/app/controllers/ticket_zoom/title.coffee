class App.TicketZoomTitle extends App.ControllerObserver
  model: 'Ticket'
  template: 'ticket_zoom/title'
  observe:
    title: true
  globalRerender: false

  events:
    'blur .js-objectTitle': 'update'

  renderPost: (object) =>
    # Make title field read-only (immutable after creation)
    titleElement = @$('.js-objectTitle')
    titleElement.ce({
      mode:      'textonly'
      multiline: false
      maxlength: 250
    })
    
    # Disable editing of title after ticket creation
    titleElement.attr('contenteditable', 'false')
    titleElement.addClass('is-disabled')
    titleElement.css({
      'cursor': 'not-allowed'
      'opacity': '0.6'
    })

  update: (e) =>
    # Title is immutable after creation - prevent any updates
    return
    
    title = $(e.target).ceg() || ''

    # update title
    return if title is @lastAttributes.title
    ticket = App.Ticket.find(@object_id)
    ticket.title = title

    # reset article - should not be resubmitted on next ticket update
    ticket.article = undefined

    ticket.save()

    App.TaskManager.mute(@taskKey)

    # update taskbar with new meta data
    App.TaskManager.touch(@taskKey)

    App.Event.trigger('overview:fetch')
