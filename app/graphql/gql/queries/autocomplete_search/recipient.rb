# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Gql::Queries
  class AutocompleteSearch::Recipient < AutocompleteSearch::User

    description 'Search for recipients'

    argument :input, Gql::Types::Input::AutocompleteSearch::RecipientInputType, required: true, description: 'The input object for the recipient autocomplete search'

    type [Gql::Types::AutocompleteSearch::RecipientEntryType], null: false

    def find_users(query:, limit:)
      users = ::User.search(
        query:,
        limit:,
        current_user: context.current_user,
      )
      
      # Filter out current user for recipient searches
      users.reject { |user| user.id == context.current_user&.id }
    end

    def post_process(results, input:)
      results.flat_map do |user|
        case input[:contact]
        when 'phone'
          user_phone_contacts(user)
        else
          user_email_contact(user)
        end
      end.map { |user| coerce_to_result(user) }
    end

    def coerce_to_result(contact)
      {
        value:   contact[:contact],
        label:   contact[:contact],
        heading: contact[:name],
      }
    end

    private

    def user_phone_contacts(user)
      contacts = []

      if user.mobile.present?
        contacts.push({
                        name:    user.fullname,
                        contact: user.mobile,
                      })
      end

      if user.phone.present?
        contacts.push({
                        name:    user.fullname,
                        contact: user.phone,
                      })
      end

      contacts
    end

    def user_email_contact(user)
      return [] if user.email.empty?

      {
        name:    user.fullname,
        contact: user.email,
      }
    end
  end
end
