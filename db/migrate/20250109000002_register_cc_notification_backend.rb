# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class RegisterCcNotificationBackend < ActiveRecord::Migration[7.2]
  def up
    # Remove existing if present
    existing = Setting.find_by(name: '9300_cc_notification')
    existing.destroy if existing

    # Register backend
    Setting.create_if_not_exists(
      title:       'Defines transaction backend for CC notifications.',
      name:        '9300_cc_notification',
      area:        'Transaction::Backend::Async',
      description: 'Defines the transaction backend to send CC-related notifications.',
      options:     {},
      state:       'Transaction::CcNotification',
      frontend:    false
    )
  end

  def down
    setting = Setting.find_by(name: '9300_cc_notification')
    setting.destroy if setting
  end
end

