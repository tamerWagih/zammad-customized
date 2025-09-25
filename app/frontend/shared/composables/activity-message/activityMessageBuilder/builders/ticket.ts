// Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

import type { Ticket } from '#shared/graphql/types.ts'
import { i18n } from '#shared/i18n.ts'

import type { ActivityMessageBuilder } from '../types.ts'

const path = (metaObject: Ticket) => {
  return `tickets/${metaObject.internalId}`
}

const messageText = (
  type: string,
  authorName: string,
  metaObject?: Ticket,
): Maybe<string> => {
  if (!metaObject) {
    return i18n.t('You can no longer see the ticket.')
  }

  const objectTitle = metaObject.title || '-'

  // Debug logging for notification types
  if (type.includes('shared') || type.includes('Approval')) {
    console.log('DEBUG: ticket.ts messageText called with type:', type, 'author:', authorName, 'title:', objectTitle)
  }

  switch (type) {
    case 'create':
      return i18n.t('%s created ticket |%s|', authorName, objectTitle)
    case 'update':
      return i18n.t('%s updated ticket |%s|', authorName, objectTitle)
    case 'Approval request':
      return i18n.t('%s requested approval on |%s|', authorName, objectTitle)
    case 'Approval approved':
      return i18n.t('Approval approved for |%s| by %s', objectTitle, authorName)
    case 'Approval rejected':
      return i18n.t('Approval rejected for |%s| by %s', objectTitle, authorName)
    case 'Ticket shared with you':
      return i18n.t('%s shared ticket |%s| with you', authorName, objectTitle)
    case 'Share revoked':
      return i18n.t('%s revoked a share on |%s|', authorName, objectTitle)
    case 'reminder_reached':
      return i18n.t('Pending reminder reached for ticket |%s|', objectTitle)
    case 'escalation':
      return i18n.t('Ticket |%s| has escalated!', objectTitle)
    case 'escalation_warning':
      return i18n.t('Ticket |%s| will escalate soon!', objectTitle)
    case 'update.merged_into':
      return i18n.t('Ticket |%s| was merged into another ticket', objectTitle)
    case 'update.received_merge':
      return i18n.t('Another ticket was merged into ticket |%s|', objectTitle)
    default:
      // Fallback: show raw type to avoid "Unknown action" log spam
      return i18n.t('%s on |%s|', type, objectTitle)
  }
}

export default <ActivityMessageBuilder>{
  path,
  messageText,
  model: 'Ticket',
}
