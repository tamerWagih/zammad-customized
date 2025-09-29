# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Queries
    class TicketShares < BaseQuery
      description 'Get ticket shares'

      argument :ticket_id, GraphQL::Types::ID, required: true, description: 'ID of the ticket'

      type [Gql::Types::Ticket::ShareType], null: false

      def resolve(ticket_id:)
        ticket = Ticket.find(ticket_id)
        
            # Check permissions - only agents and admins can view shares
            unless ticket.agent_access?(context[:current_user]) || context[:current_user].role?('Admin')
              raise Exceptions::NotAuthorized, 'You need agent or admin permissions to view ticket shares'
            end

        ticket.shares.includes(:shared_with).order(created_at: :desc)
      rescue ActiveRecord::RecordNotFound
        []
      rescue Exceptions::NotAuthorized
        []
      end
    end
  end
end



