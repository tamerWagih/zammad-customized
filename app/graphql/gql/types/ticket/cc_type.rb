# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Types
    module Ticket
      class CcType < BaseObject
        description 'Ticket CC (Carbon Copy)'

        field :id, GraphQL::Types::ID, null: false, description: 'Unique identifier of the CC record'
        field :ticket_id, GraphQL::Types::ID, null: false, description: 'ID of the ticket'
        field :user_id, GraphQL::Types::ID, null: false, description: 'ID of the CC\'d user'
        field :user_name, String, null: false, description: 'Name of the CC\'d user'
        field :permissions, [String], null: false, description: 'Permissions granted to the CC\'d user'
        field :message, String, null: true, description: 'Optional message for the CC'
        field :created_by_id, GraphQL::Types::ID, null: true, description: 'ID of the user who created the CC'
        field :created_by_name, String, null: true, description: 'Name of the user who created the CC'
        field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When the CC was created'
        field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When the CC was last updated'

        # Helper methods
        def user_name
          object.user_name
        end

        def created_by_name
          object.created_by_name
        end
      end
    end
  end
end
