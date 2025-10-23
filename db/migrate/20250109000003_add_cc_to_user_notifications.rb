# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddCcToUserNotifications < ActiveRecord::Migration[7.2]
  def up
    cc_config = {
      'criteria' => {
        'owned_by_me'     => true,
        'owned_by_nobody' => true,
        'subscribed'      => true,
        'no'              => false
      },
      'channel' => {
        'email'  => true,
        'online' => true
      }
    }

    users_updated = 0
    User.where(active: true).find_each do |user|
      prefs = user.preferences || {}
      notification_config = prefs['notification_config'] || {}
      matrix = notification_config['matrix'] || {}

      next if matrix.key?('cc')

      matrix['cc'] = cc_config
      notification_config['matrix'] = matrix
      prefs['notification_config'] = notification_config
      user.preferences = prefs

      begin
        user.save!(touch: false)
        users_updated += 1
      rescue => e
        Rails.logger.error "[CC_NOTIFICATION] Failed to update user ##{user.id}: #{e.message}"
      end
    end

    Rails.logger.info "[CC_NOTIFICATION] Updated #{users_updated} users with CC notifications"
  end

  def down
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
        Rails.logger.error "[CC_NOTIFICATION] Failed to update user ##{user.id}: #{e.message}"
      end
    end

    Rails.logger.info "[CC_NOTIFICATION] Removed CC from #{users_updated} users"
  end
end

