# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Mutations
    class TicketCcDestroy < BaseMutation
      description 'Remove a ticket CC (Carbon Copy)'

      argument :ticket_id,
               GraphQL::Types::ID,
               required: true,
               loads: Gql::Types::TicketType,
               as: :ticket,
               description: 'ID of the ticket'

      argument :cc_id,
               GraphQL::Types::ID,
               required: true,
               loads: Gql::Types::Ticket::CcType,
               as: :cc,
               description: 'ID of the CC to remove'

      type Gql::Types::Ticket::CcType, null: false

      def resolve(ticket:, cc:)
        Service::Ticket::Cc::Destroy
          .new(current_user: context.current_user)
          .execute(cc: cc)
      rescue Exceptions::Forbidden => e
        raise GraphQL::ExecutionError, e.message
      end
    end
  end
end
