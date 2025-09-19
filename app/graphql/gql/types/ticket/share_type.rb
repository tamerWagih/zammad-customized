module Gql
  module Types
    module Ticket
      class ShareType < BaseObject
        description 'Ticket share'

        field :id, ID, null: false
        field :ticket_id, ID, null: false
        field :shared_with_id, ID, null: false
        field :shared_with, UserType, null: true
        field :permissions, [String], null: false
        field :message, String, null: true
        field :created_at, GraphQL::Types::ISO8601DateTime, null: false
        field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

        def shared_with
          return nil unless object.shared_with_id

          User.find_by(id: object.shared_with_id)
        end
      end
    end
  end
end



