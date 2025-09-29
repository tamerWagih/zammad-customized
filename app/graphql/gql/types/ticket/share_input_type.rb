# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Types
    module Ticket
      class ShareInputType < BaseInputObject
        description 'Input for creating or updating a ticket share'

        argument :ticket_id, GraphQL::Types::ID, required: true, description: 'ID of the ticket'
        argument :shared_with_id, GraphQL::Types::ID, required: true, description: 'ID of the user to share with'
        argument :permissions, [String], required: true, description: 'List of permissions (read, comment, edit)'
        argument :message, String, required: false, description: 'Message for the share request'
      end

      class ShareActionInputType < BaseInputObject
        description 'Input for updating or revoking a ticket share'

        argument :id, GraphQL::Types::ID, required: true, description: 'ID of the share request'
        argument :permissions, [String], required: false, description: 'Updated list of permissions'
        argument :message, String, required: false, description: 'Additional message for the share update'
      end
    end
  end
end