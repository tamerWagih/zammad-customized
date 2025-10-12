# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddApprovalShareToExistingUserNotifications < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup
    return if !Setting.exists?(name: 'system_init_done')

    Rails.logger.info "[USER_NOTIFICATION_FIX] 🔧 Adding approval/share to existing user notifications..."

    # Define approval and share notification configs
    approval_config = {
      'criteria' => {
        'owned_by_me'     => true,
        'owned_by_nobody' => true,
        'subscribed'      => true,
        'no'              => false,
      },
      'channel' => {
        'email'  => true,
        'online' => true,
      }
    }

    share_config = {
      'criteria' => {
        'owned_by_me'     => true,
        'owned_by_nobody' => true,
        'subscribed'      => true,
        'no'              => false,
      },
      'channel' => {
        'email'  => true,
        'online' => true,
      }
    }

    # Update all active agent users
    users_updated = 0
    User.where(active: true).find_each do |user|
      # Only update agents (users with ticket.agent permission)
      next unless user.permissions?('ticket.agent')

      # Get current preferences
      prefs = user.preferences || {}
      notification_config = prefs['notification_config'] || {}
      matrix = notification_config['matrix'] || {}

      # Skip if already has approval and share
      if matrix.key?('approval') && matrix.key?('share')
        Rails.logger.debug "[USER_NOTIFICATION_FIX] ⏭️  Skipping user ##{user.id} (#{user.email}) - already has approval/share"
        next
      end

      # Add approval and share to matrix
      matrix['approval'] = approval_config unless matrix.key?('approval')
      matrix['share'] = share_config unless matrix.key?('share')

      # Update notification config
      notification_config['matrix'] = matrix
      prefs['notification_config'] = notification_config

      # Save user preferences
      user.preferences = prefs
      user.save!(touch: false) # Don't update updated_at timestamp

      users_updated += 1
      Rails.logger.info "[USER_NOTIFICATION_FIX] ✅ Updated user ##{user.id} (#{user.email})"
    end

    Rails.logger.info "[USER_NOTIFICATION_FIX] ✅ Updated #{users_updated} existing users with approval/share notifications"
  end

  def down
    Rails.logger.info "[USER_NOTIFICATION_FIX] ⬇️  Removing approval/share from user notifications..."

    users_updated = 0
    User.where(active: true).find_each do |user|
      next unless user.permissions?('ticket.agent')

      prefs = user.preferences || {}
      notification_config = prefs['notification_config'] || {}
      matrix = notification_config['matrix'] || {}

      next unless matrix.key?('approval') || matrix.key?('share')

      matrix.delete('approval')
      matrix.delete('share')

      notification_config['matrix'] = matrix
      prefs['notification_config'] = notification_config
      user.preferences = prefs
      user.save!(touch: false)

      users_updated += 1
    end

    Rails.logger.info "[USER_NOTIFICATION_FIX] ⬇️  Removed approval/share from #{users_updated} users"
  end
end

