# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Queries
    class TicketApprovals < BaseQuery
      description 'Get ticket approvals'

      argument :ticket_id, GraphQL::Types::ID, required: true, description: 'ID of the ticket'

      type [Gql::Types::Ticket::ApprovalType], null: false

      def resolve(ticket_id:)
        ticket = Ticket.find(ticket_id)
        
            # Check permissions - only agents and admins can view approvals
            unless ticket.agent_access?(context[:current_user]) || context[:current_user].role?('Admin')
              raise Exceptions::NotAuthorized, 'You need agent or admin permissions to view ticket approvals'
            end

        ticket.approvals.includes(:approver).order(created_at: :desc)
      rescue ActiveRecord::RecordNotFound
        []
      rescue Exceptions::NotAuthorized
        []
      end
    end
  end
end



