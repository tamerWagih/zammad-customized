module Gql
  module Queries
    class TicketShares < BaseQuery
      description 'Get ticket shares'

      argument :ticket_id, String, required: true

      type [Gql::Types::Ticket::ShareType], null: false

      def resolve(ticket_id:)
        ::Ticket::Share.where(ticket_id: ticket_id)
      end
    end
  end
end



