# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Controllers::CustomFilterAttributesControllerPolicy < Controllers::ApplicationControllerPolicy
  def index?
    # Allow agents and customers to see safe attribute lists for custom filters
    user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
  end
end

