module Gql
  module Mutations
    module Ticket
      module Share
        class Revoke < BaseMutation
          description 'Revoke a ticket share'

          argument :input, Gql::Types::Ticket::ShareActionInputType, required: true

          field :success, Boolean, null: false
          field :errors, [String], null: false

          def resolve(input:)
            share = Ticket::Share.find_by(id: input[:share_id])

            if share.nil?
              return {
                success: false,
                errors: ['Share not found']
              }
            end

            share.destroy!

            {
              success: true,
              errors: []
            }
          rescue StandardError => e
            {
              success: false,
              errors: [e.message]
            }
          end
        end
      end
    end
  end
end
