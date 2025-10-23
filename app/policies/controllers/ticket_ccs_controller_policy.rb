# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Controllers::TicketCcsControllerPolicy < Controllers::ApplicationControllerPolicy
  # Allow both agents and customers to manage CCs
  permit! %i[index create destroy], to: ['ticket.agent', 'ticket.customer']
end
