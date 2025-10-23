# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Cc::Create < Service::BaseWithCurrentUser
  def execute(ticket:, user_id:, message: nil)
    Pundit.authorize current_user, ticket, :update?

    user = User.find(user_id)

    # Only agents and customers can be CC'd
    unless user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
      raise Exceptions::UnprocessableEntity,
            __('Only agents and customers can be CC\'d. %s does not have the required permissions.') % user.fullname
    end

    # Check if already CC'd
    if ticket.ccs.exists?(user_id: user.id)
      raise Exceptions::UnprocessableEntity,
            __('%s is already CC\'d on this ticket.') % user.fullname
    end

    # Create CC record
    cc = ticket.ccs.create!(
      user:          user,
      message:       message,
      created_by_id: current_user.id,
      updated_by_id: current_user.id
    )

    # NO manual notification calls!
    # Transaction::CcNotification will be triggered automatically

    cc
  end
end

