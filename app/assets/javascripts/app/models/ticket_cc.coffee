# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class App.TicketCc extends App.Model
  @configure 'TicketCc', 'id', 'ticket_id', 'user_id', 'permissions', 'message', 'created_at', 'updated_at'
  @extend Spine.Model.Ajax
  @url: @apiPath + '/tickets'
  @configure_attributes = [
    { name: 'id',                display: __('ID'),                tag: 'input',    type: 'text', limit: 100, null: true, readonly: 1 },
    { name: 'ticket_id',         display: __('Ticket'),           tag: 'input',    type: 'text', limit: 100, null: false, readonly: 1 },
    { name: 'user_id',           display: __('User'),             tag: 'select',   multiple: false, limit: 100, null: false, relation: 'User' },
    { name: 'permissions',       display: __('Permissions'),      tag: 'select',   multiple: true, limit: 100, null: false, options: { 'read': __('Read'), 'comment': __('Comment'), 'full': __('Full') }, default: ['read', 'comment'] },
    { name: 'message',           display: __('Message'),          tag: 'textarea', rows: 4, limit: 500, null: true },
    { name: 'created_at',        display: __('Created'),          tag: 'datetime', null: true, readonly: 1 },
    { name: 'updated_at',        display: __('Updated'),          tag: 'datetime', null: true, readonly: 1 }
  ]
  @configure_delete = true
  @configure_clone = true
  @configure_overview = ['user', 'permissions', 'created_at']

  @urlFor: (action, id) ->
    if action is 'create'
      return "#{@url}/#{@ticket_id}/ccs"
    else if action is 'update' or action is 'delete'
      return "#{@url}/#{@ticket_id}/ccs/#{id}"
    else if action is 'index'
      return "#{@url}/#{@ticket_id}/ccs"
    else
      return super

  @findByTicket: (ticket_id) ->
    @findAllByAttribute('ticket_id', ticket_id)

  @findByUser: (user_id) ->
    @findAllByAttribute('user_id', user_id)

  hasReadAccess: ->
    @permissions?.includes('read') || @hasFullAccess()

  hasCommentAccess: ->
    @permissions?.includes('comment') || @hasFullAccess()

  hasFullAccess: ->
    @permissions?.includes('full')

  canRead: ->
    @hasReadAccess()

  canComment: ->
    @hasCommentAccess()

  canEdit: ->
    @hasFullAccess()

  permissionsText: ->
    if @hasFullAccess()
      __('Full Access')
    else if @hasCommentAccess()
      __('Read and Comment')
    else
      __('Read Only')

