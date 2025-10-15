# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class RegisterCcNotificationBackend < ActiveRecord::Migration[7.2]
  def up
    # Register Transaction::CcNotification backend
    Setting.create_if_not_exists(
      title:       'Defines transaction backend for CC notifications.',
      name:        '9300_cc_notification',
      area:        'Transaction::Backend::Async',
      description: 'Defines the transaction backend to send CC-related notifications.',
      options:     {},
      state:       'Transaction::CcNotification',
      frontend:    false
    )

    Rails.logger.info '[MIGRATION] ✅ Registered Transaction::CcNotification backend'
  end

  def down
    # Remove the setting
    Setting.find_by(name: '9300_cc_notification')&.destroy

    Rails.logger.info '[MIGRATION] ⬇️  Removed CC notification backend'
  end
end

