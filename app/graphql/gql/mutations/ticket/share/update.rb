module Gql
  module Mutations
    module Ticket
      module Share
        class Update < BaseMutation
          description 'Update a ticket share'

          argument :input, Gql::Types::Ticket::ShareActionInputType, required: true

          field :share, Gql::Types::Ticket::ShareType, null: true
          field :errors, [String], null: false

          def resolve(input:)
            share = ::Ticket::Share.find(input[:id])

            share = Service::Ticket::Share::Update
              .new(current_user: context[:current_user])
              .execute(
                share:,
                attributes: {
                  message: input[:message],
                  expires_at: input[:expires_at]
                }.compact
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
