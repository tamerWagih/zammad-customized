# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Approval::List < Service::BaseWithCurrentUser
  def execute(ticket:)
    Pundit.authorize current_user, ticket, :show?

    scope = ticket.approvals.includes(:approver, :requester).order(created_at: :desc)

    return scope if can_manage_approvals?(ticket)

    if current_user
      scope.where(approver_id: current_user.id).or(scope.where(requester_id: current_user.id)).distinct
    else
      scope.none
    end
  end

  private

  def can_manage_approvals?(ticket)
    policy = Pundit.policy!(current_user, ticket)
    policy&.update?
  end
end
