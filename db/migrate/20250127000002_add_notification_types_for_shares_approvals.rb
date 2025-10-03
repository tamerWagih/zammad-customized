# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddNotificationTypesForSharesApprovals < ActiveRecord::Migration[7.2]
  def up
    # Add notification types for share and approval deletions
    TypeLookup.create_if_not_exists(name: 'Share Deleted')
    TypeLookup.create_if_not_exists(name: 'Approval Request Deleted')
  end

  def down
    # Remove the notification types
    TypeLookup.find_by(name: 'Share Deleted')&.destroy
    TypeLookup.find_by(name: 'Approval Request Deleted')&.destroy
  end
end
