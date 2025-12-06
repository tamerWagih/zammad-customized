# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Cc::Create < Service::BaseWithCurrentUser
  def execute(ticket:, user_id:, message: nil)
    Pundit.authorize current_user, ticket, :update?

    cc_user = User.find(user_id)

    # Prevent CC'ing yourself
    if cc_user.id == current_user.id
      raise Exceptions::UnprocessableEntity,
            __('You cannot CC yourself on a ticket.')
    end

    # Prevent CC'ing the ticket owner (they already have access)
    if ticket.owner_id == cc_user.id
      raise Exceptions::UnprocessableEntity,
            __('User %s is already the ticket owner and has access.') % cc_user.fullname
    end

    # Prevent CC'ing the ticket customer (they already have access)
    if ticket.customer_id == cc_user.id
      raise Exceptions::UnprocessableEntity,
            __('User %s is already the ticket customer and has access.') % cc_user.fullname
    end

    # Check if user is already CC'd
    if ticket.ccs.exists?(user_id: cc_user.id)
      raise Exceptions::UnprocessableEntity,
            __('User %s is already CC\'d on this ticket. Please update the existing CC record instead.') % cc_user.fullname
    end

    cc = ticket.ccs.create!(
      user:        cc_user,
      created_by:  current_user,
      message:     message
    )

    # Transaction::CcNotification will be triggered automatically via callbacks

    cc
  end
end

