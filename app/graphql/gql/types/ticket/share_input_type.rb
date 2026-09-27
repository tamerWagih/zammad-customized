module Gql
  module Types
    module Ticket
      class ShareInputType < BaseInputObject
        description 'Input for creating or updating a ticket share'

        argument :ticket_id, GraphQL::Types::ID, required: true, description: 'ID of the ticket'
        argument :group_id, GraphQL::Types::ID, required: true, description: 'ID of the group to share with'
        argument :message, String, required: false, description: 'Message for the share request'
      end
    end
  end
end
