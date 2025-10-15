# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddCcToUserNotifications < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup
    return if !Setting.exists?(name: 'system_init_done')

    Rails.logger.info "[USER_NOTIFICATION_FIX] 🔧 Adding CC to existing user notifications..."

    # Define CC notification config
    cc_config = {
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
    agent_users = User.joins('INNER JOIN roles_users ON roles_users.user_id = users.id')
                     .joins('INNER JOIN roles ON roles.id = roles_users.role_id')
                     .joins('INNER JOIN permissions_roles ON permissions_roles.role_id = roles.id')
                     .joins('INNER JOIN permissions ON permissions.id = permissions_roles.permission_id')
                     .where(active: true)
                     .where(permissions: { name: 'ticket.agent' })
                     .distinct
    
    agent_users.find_each do |user|
      # Get current preferences
      prefs = user.preferences || {}
      notification_config = prefs['notification_config'] || {}
      matrix = notification_config['matrix'] || {}

      # Skip if already has CC
      if matrix.key?('cc')
        Rails.logger.debug "[USER_NOTIFICATION_FIX] ⏭️  Skipping user ##{user.id} (#{user.email}) - already has CC"
        next
      end

      # Add CC to matrix
      matrix['cc'] = cc_config

      # Update notification config
      notification_config['matrix'] = matrix
      prefs['notification_config'] = notification_config

      # Save user preferences
      user.preferences = prefs
      user.save!(touch: false) # Don't update updated_at timestamp

      users_updated += 1
      Rails.logger.info "[USER_NOTIFICATION_FIX] ✅ Updated user ##{user.id} (#{user.email})"
    end

    Rails.logger.info "[USER_NOTIFICATION_FIX] ✅ Updated #{users_updated} existing users with CC notifications"
  end

  def down
    Rails.logger.info "[USER_NOTIFICATION_FIX] ⬇️  Removing CC from user notifications..."

    users_updated = 0
    agent_users = User.joins('INNER JOIN roles_users ON roles_users.user_id = users.id')
                     .joins('INNER JOIN roles ON roles.id = roles_users.role_id')
                     .joins('INNER JOIN permissions_roles ON permissions_roles.role_id = roles.id')
                     .joins('INNER JOIN permissions ON permissions.id = permissions_roles.permission_id')
                     .where(active: true)
                     .where(permissions: { name: 'ticket.agent' })
                     .distinct
    
    agent_users.find_each do |user|
      prefs = user.preferences || {}
      notification_config = prefs['notification_config'] || {}
      matrix = notification_config['matrix'] || {}

      next unless matrix.key?('cc')

      matrix.delete('cc')

      notification_config['matrix'] = matrix
      prefs['notification_config'] = notification_config
      user.preferences = prefs
      user.save!(touch: false)

      users_updated += 1
    end

    Rails.logger.info "[USER_NOTIFICATION_FIX] ⬇️  Removed CC from #{users_updated} users"
  end
end

