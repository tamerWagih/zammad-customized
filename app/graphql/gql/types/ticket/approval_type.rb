# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Types
    module Ticket
      class ApprovalType < BaseObject
        description 'Ticket approval type'

        field :id, GraphQL::Types::ID, null: false
        field :ticket_id, GraphQL::Types::ID, null: false
        field :approver_id, GraphQL::Types::ID, null: false
        field :approver, Gql::Types::UserType, null: true
        field :requester_id, GraphQL::Types::ID, null: false
        field :requester, Gql::Types::UserType, null: true
        field :status, String, null: false
        field :priority, String, null: false
        field :message, String, null: true
        field :created_at, GraphQL::Types::ISO8601DateTime, null: false
        field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

        def approver
          object.approver
        end

        def requester
          object.requester
        end
      end
    end
  end
end
