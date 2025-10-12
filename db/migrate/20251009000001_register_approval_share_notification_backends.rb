# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class RegisterApprovalShareNotificationBackends < ActiveRecord::Migration[7.2]
  def up
    # Register Transaction::ApprovalNotification backend
    Setting.create_if_not_exists(
      title:       'Defines transaction backend for approval notifications.',
      name:        '9100_approval_notification',
      area:        'Transaction::Backend::Async',
      description: 'Defines the transaction backend to send approval-related notifications.',
      options:     {},
      state:       'Transaction::ApprovalNotification',
      frontend:    false
    )

    # Register Transaction::ShareNotification backend
    Setting.create_if_not_exists(
      title:       'Defines transaction backend for share notifications.',
      name:        '9200_share_notification',
      area:        'Transaction::Backend::Async',
      description: 'Defines the transaction backend to send share-related notifications.',
      options:     {},
      state:       'Transaction::ShareNotification',
      frontend:    false
    )

    Rails.logger.info '[MIGRATION] ✅ Registered Transaction::ApprovalNotification backend'
    Rails.logger.info '[MIGRATION] ✅ Registered Transaction::ShareNotification backend'
  end

  def down
    # Remove the settings
    Setting.find_by(name: '9100_approval_notification')&.destroy
    Setting.find_by(name: '9200_share_notification')&.destroy

    Rails.logger.info '[MIGRATION] ⬇️  Removed approval and share notification backends'
  end
end

