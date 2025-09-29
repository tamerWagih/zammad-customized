# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

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
            ticket = Ticket.find(input[:ticket_id])
            
            # Check permissions - only agents and admins can create approval requests
            unless ticket.agent_access?(context[:current_user]) || context[:current_user].role?('Admin')
              return {
                approval: nil,
                errors: ['You need agent or admin permissions to create approval requests for this ticket']
              }
            end

            # Validate approver exists and is an agent
            approver = User.find(input[:approver_id])
            unless approver.agent?
              return {
                approval: nil,
                errors: ['Approver must be an agent or admin']
              }
            end

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
          rescue ActiveRecord::RecordNotFound => e
            {
              approval: nil,
              errors: [e.message]
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
