# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Types
    module Ticket
      class ApprovalInputType < BaseInputObject
        description 'Input for creating a ticket approval request'

        argument :ticket_id, GraphQL::Types::ID, required: true, description: 'ID of the ticket'
        argument :approver_id, GraphQL::Types::ID, required: true, description: 'ID of the user who will approve'
        argument :message, String, required: false, description: 'Message for the approval request'
      end

      class ApprovalActionInputType < BaseInputObject
        description 'Input for approving or rejecting a ticket approval'

        argument :id, GraphQL::Types::ID, required: true, description: 'ID of the approval request'
        argument :message, String, required: false, description: 'Additional message for the approval decision'
      end
    end
  end
end