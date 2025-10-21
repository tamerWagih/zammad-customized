# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Controllers::ObjectManagerAttributesControllerPolicy < Controllers::ApplicationControllerPolicy
  def index?
    user.permissions?('ticket.agent') || user.permissions?('ticket.customer') || user.permissions?('admin.object')
  end

  default_permit!('admin.object')
end
