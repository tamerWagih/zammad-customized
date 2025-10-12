# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Queries
    class TicketShares < BaseQuery
      description 'Get ticket shares'

      argument :ticket_id,
               GraphQL::Types::ID,
               required: true,
               loads: Gql::Types::TicketType,
               as: :ticket,
               description: 'ID of the ticket'

      type [Gql::Types::Ticket::ShareType], null: false

      def resolve(ticket:)
        Service::Ticket::Share::List
          .new(current_user: context.current_user)
          .execute(ticket:)
      end
    end
  end
end
