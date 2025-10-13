# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::CC::List < Service::BaseWithCurrentUser
  def execute(ticket:)
    Pundit.authorize current_user, ticket, :show?
    
    ticket.ccs.includes(:user, :created_by).order(created_at: :desc)
  end
end

