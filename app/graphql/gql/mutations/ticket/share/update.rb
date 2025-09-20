# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Mutations
    module Ticket
      module Share
        class Update < BaseMutation
          description 'Update a ticket share'

          argument :input, Gql::Types::Ticket::ShareActionInputType, required: true

          field :share, Gql::Types::Ticket::ShareType, null: true
          field :errors, [String], null: false

          def resolve(input:)
            share = Ticket::Share.find(input[:id])
            ticket = share.ticket
            
            # Check permissions - only agents and admins can update shares
            unless ticket.agent_access?(context[:current_user]) || context[:current_user].role?('Admin')
              return {
                share: nil,
                errors: ['You need agent or admin permissions to update shares for this ticket']
              }
            end

            # Validate permissions if provided
            if input[:permissions]
              valid_permissions = %w[read comment edit]
              invalid_permissions = input[:permissions] - valid_permissions
              if invalid_permissions.any?
                return {
                  share: nil,
                  errors: ["Invalid permissions: #{invalid_permissions.join(', ')}"]
                }
              end
            end

            share.update!(
              permissions: input[:permissions] || share.permissions,
              message: input[:message] || share.message
            )

            {
              share: share,
              errors: []
            }
          rescue ActiveRecord::RecordNotFound
            {
              share: nil,
              errors: ['Share not found']
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
