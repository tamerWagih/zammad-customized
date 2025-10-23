# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Controllers::UsersControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! %i[import_example import_start unlock], to: 'admin.user'
  permit! %i[history create update], to: ['ticket.agent', 'admin.user']
  permit! %i[search], to: ['ticket.agent', 'admin.user', 'ticket.customer']
end
