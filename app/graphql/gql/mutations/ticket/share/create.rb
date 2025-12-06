module Gql
  module Mutations
    module Ticket
      module Share
        class Create < BaseMutation
          description 'Create a new ticket share'

          argument :input, Gql::Types::Ticket::ShareInputType, required: true

          field :share, Gql::Types::Ticket::ShareType, null: true
          field :errors, [String], null: false

          def resolve(input:)
            ticket = ::Ticket.find(input[:ticket_id])

            share = Service::Ticket::Share::Create
              .new(current_user: context[:current_user])
              .execute(
                ticket:     ticket,
                group_id:   input[:group_id],
                message:    input[:message]
              )

            {
              share: share,
              errors: []
            }
          rescue ActiveRecord::RecordNotFound => e
            {
              share: nil,
              errors: [e.message]
            }
          rescue StandardError => e
            {
              share: nil,
              errors: [e.message]
            }
          end
        end
      end
    end
  end
end
