# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Controllers::TicketSharesControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! %i[index create revoke destroy], to: 'ticket.agent'
end
