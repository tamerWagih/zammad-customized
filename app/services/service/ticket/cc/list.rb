# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Cc::List < Service::BaseWithCurrentUser
  def execute(ticket:)
    Pundit.authorize current_user, ticket, :show?

    scope = ticket.ccs.includes(:user, :created_by)

    return scope.order(created_at: :desc) if can_manage_ccs?(ticket)

    # Non-managers can only see their own CC records
    if current_user
      scope.where(user_id: current_user.id).order(created_at: :desc)
    else
      scope.none
    end
  end

  private

  def can_manage_ccs?(ticket)
    policy = Pundit.policy!(current_user, ticket)
    policy&.update?
  end
end

