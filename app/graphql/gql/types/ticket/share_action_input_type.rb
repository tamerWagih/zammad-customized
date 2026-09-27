module Gql
  module Types
    module Ticket
      class ShareActionInputType < BaseInputObject
        description 'Input for updating or revoking a ticket share'

        argument :id, GraphQL::Types::ID, required: true, description: 'ID of the share request'
        argument :message, String, required: false, description: 'Additional message for the share update'
      end
    end
  end
end
