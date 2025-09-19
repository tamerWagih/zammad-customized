module Gql
  module Types
    module Ticket
      class ShareInputType < BaseInputObject
        description 'Input for ticket share operations'

        argument :ticket_id, ID, required: true
        argument :shared_with_id, ID, required: true
        argument :permissions, [String], required: true
        argument :message, String, required: false
      end
    end
  end
end



