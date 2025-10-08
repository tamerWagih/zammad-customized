# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class ForceFixNotificationDefaults < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup
    return if !Setting.exists?(name: 'system_init_done')

    Rails.logger.info "[NOTIFICATION_FIX] 🔧 Force fixing notification defaults..."

    # Get the current setting
    setting = Setting.find_by(name: 'ticket_agent_default_notifications')
    if !setting
      Rails.logger.error "[NOTIFICATION_FIX] ❌ Setting not found!"
      return
    end

    Rails.logger.info "[NOTIFICATION_FIX] 📋 Current state keys: #{setting.state&.keys || 'nil'}"
    Rails.logger.info "[NOTIFICATION_FIX] 📋 Current initial keys: #{setting.state_initial&.keys || 'nil'}"

    # Force create the complete state
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

    # Force update both states
    setting.update!(
      state: complete_state,
      state_initial: complete_state
    )

    Rails.logger.info "[NOTIFICATION_FIX] ✅ Notification defaults force updated"
    Rails.logger.info "[NOTIFICATION_FIX] 📋 New state keys: #{setting.state.keys}"
    Rails.logger.info "[NOTIFICATION_FIX] 📋 New initial keys: #{setting.state_initial.keys}"
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
