# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Cc::Destroy < Service::BaseWithCurrentUser
  def execute(cc:)
    ticket = cc.ticket
    Pundit.authorize current_user, ticket, :update?
    
    # Store data before destroy for notification
    cc_data = {
      id:             cc.id,
      ticket_id:      cc.ticket_id,
      user_id:        cc.user_id,
      user_name:      cc.user_name,
      created_by_id:  cc.created_by_id,
      created_by_name: cc.created_by_name,
      permissions:    cc.permissions,
      message:        cc.message
    }
    
    cc.destroy!
    
    OpenStruct.new(cc_data)
  end
end

