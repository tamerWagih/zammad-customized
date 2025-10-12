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
            share = ::Ticket::Share.find(input[:id])

            Service::Ticket::Share::Revoke
              .new(current_user: context[:current_user])
              .execute(share:)

            {
              success: true,
              errors: []
            }
          rescue ActiveRecord::RecordNotFound => e
            {
              success: false,
              errors: [e.message]
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
