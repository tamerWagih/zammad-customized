# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql
  module Mutations
    module Ticket
      module Share
        class Revoke < BaseMutation
          description 'Revoke a ticket share'

          argument :input, Gql::Types::Ticket::ShareActionInputType, required: true

          field :success, Boolean, null: false
          field :errors, [String], null: false

          def resolve(input:)
            share = Ticket::Share.find(input[:id])
            ticket = share.ticket
            
            # Check permissions - only agents and admins can revoke shares
            unless ticket.agent_access?(context[:current_user])
              return {
                success: false,
                errors: ['You need agent permissions to revoke shares for this ticket']
              }
            end

            share.destroy!

            {
              success: true,
              errors: []
            }
          rescue ActiveRecord::RecordNotFound
            {
              success: false,
              errors: ['Share not found']
            }
          rescue StandardError => e
            {
              success: false,
              errors: [e.message]
            }
          end
        end
      end
    end
  end
end
