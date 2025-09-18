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
            # Check if share already exists
            existing_share = Ticket::Share.find_by(
              ticket_id: input[:ticket_id],
              shared_with_id: input[:shared_with_id]
            )

            if existing_share
              return {
                share: nil,
                errors: ['Share already exists for this ticket and user']
              }
            end

            share = Ticket::Share.create!(
              ticket_id: input[:ticket_id],
              shared_with_id: input[:shared_with_id],
              permissions: input[:permissions],
              message: input[:message]
            )

            {
              share: share,
              errors: []
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
