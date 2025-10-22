# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Controllers::CustomFilterSelectorsControllerPolicy < Controllers::ApplicationControllerPolicy
  def preview?
    # Allow agents and customers to preview ticket selectors for custom filters
    user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
  end
end


