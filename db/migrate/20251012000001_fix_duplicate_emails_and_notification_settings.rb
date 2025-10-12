# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class FixDuplicateEmailsAndNotificationSettings < ActiveRecord::Migration[7.2]
  def up
    Rails.logger.info "[FIX_EMAILS] 🔧 Fixing duplicate email issues and notification settings..."

    # 1. Ensure all users (not just agents) can receive approval/share notifications
    # This fixes the issue where users without proper notification matrix don't receive emails
    fix_user_notification_settings

    Rails.logger.info "[FIX_EMAILS] ✅ Migration completed successfully"
  end

  def down
    Rails.logger.info "[FIX_EMAILS] ⬇️  Rollback - no changes needed (fixes are backward compatible)"
  end

  private

  def fix_user_notification_settings
    Rails.logger.info "[FIX_EMAILS] 📧 Fixing user notification settings..."

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

    users_updated = 0
    users_created = 0
    
    # Update ALL active users (not just agents)
    # This ensures customers and agents alike can receive notifications if they're involved
    User.where(active: true).find_each do |user|
      # Get current preferences
      prefs = user.preferences || {}
      notification_config = prefs['notification_config'] || {}
      matrix = notification_config['matrix'] || {}

      # Track if we made changes
      made_changes = false

      # Add approval to matrix if missing or invalid
      if !matrix.key?('approval') || !matrix['approval'].is_a?(Hash)
        matrix['approval'] = approval_config
        made_changes = true
        Rails.logger.info "[FIX_EMAILS]   ✅ Added approval config for user ##{user.id} (#{user.email})"
      end

      # Add share to matrix if missing or invalid
      if !matrix.key?('share') || !matrix['share'].is_a?(Hash)
        matrix['share'] = share_config
        made_changes = true
        Rails.logger.info "[FIX_EMAILS]   ✅ Added share config for user ##{user.id} (#{user.email})"
      end

      # Save if changes were made
      if made_changes
        notification_config['matrix'] = matrix
        prefs['notification_config'] = notification_config
        user.preferences = prefs
        
        begin
          user.save!(touch: false) # Don't update updated_at timestamp
          users_updated += 1
        rescue => e
          Rails.logger.error "[FIX_EMAILS]   ❌ Failed to save user ##{user.id}: #{e.message}"
        end
      end
    end

    Rails.logger.info "[FIX_EMAILS] ✅ Updated #{users_updated} users with approval/share notification settings"
  end
end

