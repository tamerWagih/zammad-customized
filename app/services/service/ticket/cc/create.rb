# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Cc::Create < Service::BaseWithCurrentUser
  def execute(ticket:, user_id:, message: nil)
    Pundit.authorize current_user, ticket, :update?
    
    cc_user = User.find(user_id)
    
    # Validate user is agent or customer
    unless cc_user.permissions?('ticket.agent') || cc_user.permissions?('ticket.customer')
      raise Exceptions::UnprocessableEntity, __('User must be an agent or customer')
    end
    
    # Check if already CC'd
    if ticket.ccs.exists?(user_id: cc_user.id)
      raise Exceptions::UnprocessableEntity, 
            __('User %s is already CC\'d on this ticket') % cc_user.fullname
    end
    
    # Determine permissions based on user role
    permissions = cc_user.permissions?('ticket.agent') ? ['full'] : ['read', 'comment']
    
    ticket.ccs.create!(
      user:       cc_user,
      created_by: current_user,
      permissions: permissions,
      message:    message
    )
  end
end

