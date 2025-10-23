# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Types
    module Ticket
      class CcInputType < BaseInputObject
        description 'Input for creating or updating a ticket CC'

        argument :user_id, GraphQL::Types::ID, required: true, description: 'ID of the user to CC'
        argument :message, String, required: false, description: 'Optional message for the CC'
        argument :permissions, [String], required: false, description: 'Permissions to grant (read, comment, full)'
      end
    end
  end
end
