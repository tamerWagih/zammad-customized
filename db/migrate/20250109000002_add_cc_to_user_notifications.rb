# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddCcToUserNotifications < ActiveRecord::Migration[6.1]
  def up
    Rails.logger.info '[CC_USER_NOTIFICATION] 🚀 Adding CC notification settings to all active users...'

    # CC notification config (similar to approval/share)
    # Users should receive CC notifications for tickets where they're involved
    cc_config = {
      'criteria' => {
        'owned_by_me' => true,
        'owned_by_nobody' => true,
        'subscribed' => true,
        'no' => false
      },
      'channel' => {
        'email' => true,
        'online' => true
      }
    }

    users_updated = 0
    # Update ALL active users (both agents and customers can be CC'd)
    User.where(active: true).find_each do |user|
      # Get current preferences
      prefs = user.preferences || {}
      notification_config = prefs['notification_config'] || {}
      matrix = notification_config['matrix'] || {}

      # Skip if already has cc
      if matrix.key?('cc')
        Rails.logger.debug "[CC_USER_NOTIFICATION] ⏭️  Skipping user ##{user.id} (#{user.email}) - already has cc"
        next
      end

      # Add cc to matrix
      matrix['cc'] = cc_config

      # Update notification config
      notification_config['matrix'] = matrix
      prefs['notification_config'] = notification_config

      # Save user preferences
      user.preferences = prefs
      begin
        user.save!(touch: false) # Don't update updated_at timestamp
        users_updated += 1
        Rails.logger.debug "[CC_USER_NOTIFICATION] ✅ Updated user ##{user.id} (#{user.email})"
      rescue => e
        Rails.logger.error "[CC_USER_NOTIFICATION] ❌ Failed to save user ##{user.id}: #{e.message}"
      end
    end

    Rails.logger.info "[CC_USER_NOTIFICATION] ✅ Updated #{users_updated} existing users with CC notifications"
  end

  def down
    Rails.logger.info '[CC_USER_NOTIFICATION] ⬇️  Removing CC from user notifications...'

    users_updated = 0
    User.where(active: true).find_each do |user|
      prefs = user.preferences || {}
      notification_config = prefs['notification_config'] || {}
      matrix = notification_config['matrix'] || {}

      next unless matrix.key?('cc')

      matrix.delete('cc')

      notification_config['matrix'] = matrix
      prefs['notification_config'] = notification_config
      user.preferences = prefs
      
      begin
        user.save!(touch: false)
        users_updated += 1
      rescue => e
        Rails.logger.error "[CC_USER_NOTIFICATION] ❌ Failed to save user ##{user.id} during rollback: #{e.message}"
      end
    end

    Rails.logger.info "[CC_USER_NOTIFICATION] ⬇️  Removed CC from #{users_updated} users"
  end
end

