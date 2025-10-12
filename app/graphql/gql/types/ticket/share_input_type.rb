module Gql
  module Types
    module Ticket
      class ShareInputType < BaseInputObject
        description 'Input for creating or updating a ticket share'

        argument :ticket_id, GraphQL::Types::ID, required: true, description: 'ID of the ticket'
        argument :group_id, GraphQL::Types::ID, required: true, description: 'ID of the group to share with'
        argument :message, String, required: false, description: 'Message for the share request'
        argument :expires_at, GraphQL::Types::ISO8601Date, required: false, description: 'Expiry date (inclusive)'
      end

      class ShareActionInputType < BaseInputObject
        description 'Input for updating or revoking a ticket share'

        argument :id, GraphQL::Types::ID, required: true, description: 'ID of the share request'
        argument :message, String, required: false, description: 'Additional message for the share update'
        argument :expires_at, GraphQL::Types::ISO8601Date, required: false, description: 'Updated expiry date (inclusive)'
      end
    end
  end
end
