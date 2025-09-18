module Gql
  module Mutations
    module Ticket
      module Approval
        class Create < BaseMutation
          description 'Create a new ticket approval request'

          argument :input, Gql::Types::Ticket::ApprovalInputType, required: true

          field :approval, Gql::Types::Ticket::ApprovalType, null: true
          field :errors, [String], null: false

          def resolve(input:)
            # Check if approval already exists
            existing_approval = Ticket::Approval.find_by(
              ticket_id: input[:ticket_id],
              approver_id: input[:approver_id]
            )

            if existing_approval
              return {
                approval: nil,
                errors: ['Approval request already exists for this ticket and approver']
              }
            end

            approval = Ticket::Approval.create!(
              ticket_id: input[:ticket_id],
              approver_id: input[:approver_id],
              message: input[:message],
              status: 'pending'
            )

            {
              approval: approval,
              errors: []
            }
          rescue StandardError => e
            {
              approval: nil,
              errors: [e.message]
            }
          end
        end
      end
    end
  end
end
