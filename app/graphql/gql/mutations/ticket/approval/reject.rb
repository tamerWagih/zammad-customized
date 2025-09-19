# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Mutations
    module Ticket
      module Approval
        class Reject < BaseMutation
          description 'Reject a ticket approval request'

          argument :input, Gql::Types::Ticket::ApprovalActionInputType, required: true

          field :approval, Gql::Types::Ticket::ApprovalType, null: true
          field :errors, [String], null: false

          def resolve(input:)
            approval = Ticket::Approval.find(input[:id])

            # Check permissions - only the assigned approver can reject
            unless approval.approver_id == context[:current_user].id
              return {
                approval: nil,
                errors: ['You are not authorized to reject this request']
              }
            end

            if approval.status != 'pending'
              return {
                approval: nil,
                errors: ['Approval request is not pending']
              }
            end

            approval.reject!

            {
              approval: approval,
              errors: []
            }
          rescue ActiveRecord::RecordNotFound
            {
              approval: nil,
              errors: ['Approval request not found']
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
