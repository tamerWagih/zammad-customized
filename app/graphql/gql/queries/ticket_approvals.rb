# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Queries
    class TicketApprovals < BaseQuery
      description 'Get ticket approvals'

      argument :ticket_id,
               GraphQL::Types::ID,
               required: true,
               loads: Gql::Types::TicketType,
               as: :ticket,
               description: 'ID of the ticket'

      type [Gql::Types::Ticket::ApprovalType], null: false

      def resolve(ticket:)
        Service::Ticket::Approval::List
          .new(current_user: context.current_user)
          .execute(ticket:)
      end
    end
  end
end
