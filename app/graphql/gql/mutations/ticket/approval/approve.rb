module Gql
  module Mutations
    module Ticket
      module Approval
        class Approve < BaseMutation
          description 'Approve a ticket approval request'

          argument :input, Gql::Types::Ticket::ApprovalActionInputType, required: true

          field :approval, Gql::Types::Ticket::ApprovalType, null: true
          field :errors, [String], null: false

          def resolve(input:)
            approval = Ticket::Approval.find_by(id: input[:approval_id])

            if approval.nil?
              return {
                approval: nil,
                errors: ['Approval request not found']
              }
            end

            if approval.status != 'pending'
              return {
                approval: nil,
                errors: ['Approval request is not pending']
              }
            end

            approval.update!(status: 'approved')

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
