module Gql
  module Types
    module Ticket
      class ApprovalType < BaseObject
        description 'Ticket approval request'

        field :id, ID, null: false
        field :ticket_id, ID, null: false
        field :approver_id, ID, null: false
        field :approver, UserType, null: true
        field :status, String, null: false
        field :message, String, null: true
        field :created_at, GraphQL::Types::ISO8601DateTime, null: false
        field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

        def approver
          return nil unless object.approver_id

          User.find_by(id: object.approver_id)
        end
      end
    end
  end
end
