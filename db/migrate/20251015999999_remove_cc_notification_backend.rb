# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class RemoveCcNotificationBackend < ActiveRecord::Migration[7.2]
  def up
    # Remove the potentially broken CC notification backend setting
    old_setting = Setting.find_by(name: '9300_cc_notification')
    
    if old_setting
      old_setting.destroy
      Rails.logger.info '[MIGRATION] 🗑️  Removed old/broken CC notification backend setting'
    else
      Rails.logger.info '[MIGRATION] ⏭️  No CC notification backend setting found (already clean)'
    end
    
    # Re-register it cleanly (only if the class exists - i.e., we're on feature branch)
    begin
      # Try to load the class to check if it exists
      'Transaction::CcNotification'.constantize
      
      # Class exists, register it
      Setting.create_if_not_exists(
        title:       'Defines transaction backend for CC notifications.',
        name:        '9300_cc_notification',
        area:        'Transaction::Backend::Async',
        description: 'Defines the transaction backend to send CC-related notifications.',
        options:     {},
        state:       'Transaction::CcNotification',
        frontend:    false
      )
      
      Rails.logger.info '[MIGRATION] ✅ Re-registered Transaction::CcNotification backend (clean setup)'
    rescue NameError
      # Class doesn't exist (we're on stable branch), just leave it removed
      Rails.logger.info '[MIGRATION] ⏭️  Transaction::CcNotification class not found - not re-registering (stable branch)'
    end
  end

  def down
    # Remove the setting if rolling back
    Setting.find_by(name: '9300_cc_notification')&.destroy
    
    Rails.logger.info '[MIGRATION] ⬇️  Rolled back CC notification backend removal'
  end
end

