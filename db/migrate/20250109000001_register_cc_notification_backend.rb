# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class RegisterCcNotificationBackend < ActiveRecord::Migration[6.1]
  def up
    # Remove any existing setting first (in case of conflicts from previous branch)
    existing = Setting.find_by(name: '9300_cc_notification')
    if existing
      Rails.logger.info '[MIGRATION] 🔄 Removing existing CC notification backend setting for clean re-registration'
      existing.destroy
    end

    # Register the CC notification backend
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
    setting = Setting.find_by(name: '9300_cc_notification')
    if setting
      setting.destroy
      Rails.logger.info '[MIGRATION] ⬇️ Removed CC notification backend setting'
    end
  end
end
