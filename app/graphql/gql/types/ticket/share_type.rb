# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Types
    module Ticket
      class ShareType < BaseObject
        description 'Ticket share type'

        field :id, GraphQL::Types::ID, null: false
        field :ticket_id, GraphQL::Types::ID, null: false
        field :shared_with_id, GraphQL::Types::ID, null: false
        field :shared_with, Gql::Types::UserType, null: true
        field :shared_by_id, GraphQL::Types::ID, null: false
        field :shared_by, Gql::Types::UserType, null: true
        field :permissions, [String], null: false
        field :message, String, null: true
        field :status, String, null: false
        field :expires_at, GraphQL::Types::ISO8601DateTime, null: true
        field :created_at, GraphQL::Types::ISO8601DateTime, null: false
        field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

        def shared_with
          object.shared_with
        end

        def shared_by
          object.shared_by
        end
      end
    end
  end
end
