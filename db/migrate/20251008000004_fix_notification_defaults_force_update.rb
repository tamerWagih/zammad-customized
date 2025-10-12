# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class FixNotificationDefaultsForceUpdate < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup
    return if !Setting.exists?(name: 'system_init_done')

    # Get the current setting
    setting = Setting.find_by(name: 'ticket_agent_default_notifications')
    return if !setting

    Rails.logger.info "[NOTIFICATION_FIX] 🔧 Force updating notification defaults to include approval/share"

    # Force update the setting with complete state including approval/share
    complete_state = {
      'create' => {
        criteria: {
          owned_by_me:     true,
          owned_by_nobody: true,
          subscribed:      true,
          no:              false,
        },
        channel: {
          email:  true,
          online: true,
        }
      },
      'update' => {
        criteria: {
          owned_by_me:     true,
          owned_by_nobody: true,
          subscribed:      true,
          no:              false,
        },
        channel: {
          email:  true,
          online: true,
        }
      },
      'reminder_reached' => {
        criteria: {
          owned_by_me:     true,
          owned_by_nobody: false,
          subscribed:      false,
          no:              false,
        },
        channel: {
          email:  true,
          online: true,
        }
      },
      'escalation' => {
        criteria: {
          owned_by_me:     true,
          owned_by_nobody: false,
          subscribed:      false,
          no:              false,
        },
        channel: {
          email:  true,
          online: true,
        }
      },
      'approval' => {
        criteria: {
          owned_by_me:     true,
          owned_by_nobody: true,
          subscribed:      true,
          no:              false,
        },
        channel: {
          email:  true,
          online: true,
        }
      },
      'share' => {
        criteria: {
          owned_by_me:     true,
          owned_by_nobody: true,
          subscribed:      true,
          no:              false,
        },
        channel: {
          email:  true,
          online: true,
        }
      }
    }

    # Force update both current state and initial state
    setting.update!(
      state: complete_state,
      state_initial: complete_state
    )

    Rails.logger.info "[NOTIFICATION_FIX] ✅ Notification defaults updated successfully"
    Rails.logger.info "[NOTIFICATION_FIX] 📋 Available notification types: #{complete_state.keys.join(', ')}"
  end

  def down
    # Get the current setting
    setting = Setting.find_by(name: 'ticket_agent_default_notifications')
    return if !setting

    # Remove approval and share from both states
    current_state = setting.state || {}
    initial_state = setting.state_initial || {}
    
    current_state.delete('approval')
    current_state.delete('share')
    initial_state.delete('approval')
    initial_state.delete('share')
    
    setting.update!(
      state: current_state,
      state_initial: initial_state
    )
  end
end
