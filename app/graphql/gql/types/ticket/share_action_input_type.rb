module Gql
  module Types
    module Ticket
      class ShareActionInputType < BaseInputObject
        description 'Input for ticket share actions (revoke)'

        argument :share_id, ID, required: true
      end
    end
  end
end
