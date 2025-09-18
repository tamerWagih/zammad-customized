module Gql
  module Queries
    module Ticket
      class Approvals < BaseQuery
        description 'Get ticket approvals'

        argument :ticket_id, String, required: true

        type [Gql::Types::Ticket::ApprovalType], null: false

        def resolve(ticket_id:)
          Ticket::Approval.where(ticket_id: ticket_id)
        end
      end
    end
  end
end
