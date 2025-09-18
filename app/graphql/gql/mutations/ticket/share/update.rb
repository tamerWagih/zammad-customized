module Gql
  module Mutations
    module Ticket
      module Share
        class Update < BaseMutation
          description 'Update a ticket share'

          argument :input, Gql::Types::Ticket::ShareActionInputType, required: true
          argument :permissions, [String], required: true
          argument :message, String, required: false

          field :share, Gql::Types::Ticket::ShareType, null: true
          field :errors, [String], null: false

          def resolve(input:, permissions:, message: nil)
            share = Ticket::Share.find_by(id: input[:share_id])

            if share.nil?
              return {
                share: nil,
                errors: ['Share not found']
              }
            end

            share.update!(
              permissions: permissions,
              message: message
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
