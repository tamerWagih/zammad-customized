# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Mutations
    class TicketCcCreate < BaseMutation
      description 'Create a new ticket CC (Carbon Copy)'

      argument :ticket_id,
               GraphQL::Types::ID,
               required: true,
               loads: Gql::Types::TicketType,
               as: :ticket,
               description: 'ID of the ticket'

      argument :input,
               Gql::Types::Ticket::CcInputType,
               required: true,
               description: 'CC input data'

      type Gql::Types::Ticket::CcType, null: false

      def resolve(ticket:, input:)
        Service::Ticket::Cc::Create
          .new(current_user: context.current_user)
          .execute(
            ticket: ticket,
            user_id: input[:user_id],
            message: input[:message]
          )
      rescue ActiveRecord::RecordNotFound
        raise GraphQL::ExecutionError, 'User not found'
      rescue Exceptions::UnprocessableEntity => e
        raise GraphQL::ExecutionError, e.message
      end
    end
  end
end
