# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Controllers::TicketApprovalsControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! %i[index create approve reject destroy], to: 'ticket.agent'
end

