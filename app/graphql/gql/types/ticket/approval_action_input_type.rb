module Gql
  module Types
    module Ticket
      class ApprovalActionInputType < BaseInputObject
        description 'Input for ticket approval actions (approve/reject)'

        argument :approval_id, ID, required: true
      end
    end
  end
end
