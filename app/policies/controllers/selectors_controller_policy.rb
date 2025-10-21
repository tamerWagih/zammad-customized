# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Controllers::SelectorsControllerPolicy < Controllers::ApplicationControllerPolicy
  def preview?
    user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
  end

  default_permit!('admin.*')
end
