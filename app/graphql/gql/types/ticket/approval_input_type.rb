module Gql
  module Types
    module Ticket
      class ApprovalInputType < BaseInputObject
        description 'Input for ticket approval operations'

        argument :ticket_id, ID, required: true
        argument :approver_id, ID, required: true
        argument :message, String, required: false
      end
    end
  end
end



