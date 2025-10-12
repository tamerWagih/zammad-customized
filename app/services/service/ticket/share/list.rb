# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Share::List < Service::BaseWithCurrentUser
  def execute(ticket:)
    Pundit.authorize current_user, ticket, :show?

    scope = ticket.shares.includes(:group, :shared_by)

    return scope.order(created_at: :desc) if can_manage_shares?(ticket)

    visible = scope.active_current
    if current_user
      visible = visible.or(scope.where(shared_by_id: current_user.id))
    end

    visible.distinct.order(created_at: :desc)
  end

  private

  def can_manage_shares?(ticket)
    policy = Pundit.policy!(current_user, ticket)
    policy&.update?
  end
end

