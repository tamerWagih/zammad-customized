# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Mutations
    module Ticket
      module Share
        class Create < BaseMutation
          description 'Create a new ticket share'

          argument :input, Gql::Types::Ticket::ShareInputType, required: true

          field :share, Gql::Types::Ticket::ShareType, null: true
          field :errors, [String], null: false

          def resolve(input:)
            ticket = Ticket.find(input[:ticket_id])
            
            # Check permissions - only agents and admins can create shares
            unless ticket.agent_access?(context[:current_user])
              return {
                share: nil,
                errors: ['You need agent permissions to create shares for this ticket']
              }
            end

            # Validate shared user exists
            shared_user = User.find(input[:shared_with_id])

            # Check if share already exists
            existing_share = Ticket::Share.find_by(
              ticket_id: input[:ticket_id],
              shared_with_id: input[:shared_with_id]
            )

            if existing_share
              return {
                share: nil,
                errors: ['Share already exists for this ticket and user']
              }
            end

            # Validate permissions
            valid_permissions = %w[read comment edit]
            invalid_permissions = input[:permissions] - valid_permissions
            if invalid_permissions.any?
              return {
                share: nil,
                errors: ["Invalid permissions: #{invalid_permissions.join(', ')}"]
              }
            end

            share = Ticket::Share.create!(
              ticket_id: input[:ticket_id],
              shared_with_id: input[:shared_with_id],
              permissions: input[:permissions],
              message: input[:message]
            )

            {
              share: share,
              errors: []
            }
          rescue ActiveRecord::RecordNotFound => e
            {
              share: nil,
              errors: [e.message]
            }
          rescue StandardError => e
            {
              share: nil,
              errors: [e.message]
            }
          end
        end
      end
    end
  end
end
