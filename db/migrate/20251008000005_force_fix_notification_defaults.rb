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
    Rails.logger.info "[NOTIFICATION_FIX] 📋 Current state_current keys: #{setting.state_current&.dig(:value)&.keys || 'nil'}"
    Rails.logger.info "[NOTIFICATION_FIX] 📋 Current state_initial keys: #{setting.state_initial&.dig(:value)&.keys || 'nil'}"

    # Get existing state or use empty hash
    current_state = setting.state_current&.dig(:value) || setting.state || {}
    initial_state = setting.state_initial&.dig(:value) || setting.state || {}
    
    Rails.logger.info "[NOTIFICATION_FIX] 📋 Existing state types: #{current_state.keys.join(', ')}"

    # Define approval and share notification configs to ADD
    approval_config = {
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
    
    share_config = {
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

    # ADD approval and share to existing state (don't replace!)
    current_state['approval'] = approval_config unless current_state.key?('approval')
    current_state['share'] = share_config unless current_state.key?('share')
    
    initial_state['approval'] = approval_config unless initial_state.key?('approval')
    initial_state['share'] = share_config unless initial_state.key?('share')

    # Update both state_current and state_initial (they are serialized stores)
    setting.update!(
      state_current: { value: current_state },
      state_initial: { value: initial_state }
    )

    Rails.logger.info "[NOTIFICATION_FIX] ✅ Notification defaults updated (MERGED, not replaced)"
    Rails.logger.info "[NOTIFICATION_FIX] 📋 New state_current keys: #{setting.state_current[:value].keys.join(', ')}"
    Rails.logger.info "[NOTIFICATION_FIX] 📋 New state_initial keys: #{setting.state_initial[:value].keys.join(', ')}"
  end

  def down
    # Get the current setting
    setting = Setting.find_by(name: 'ticket_agent_default_notifications')
    return if !setting

    # Remove approval and share from both state_current and state_initial
    current_state = setting.state_current&.dig(:value) || {}
    initial_state = setting.state_initial&.dig(:value) || {}
    
    current_state.delete('approval')
    current_state.delete('share')
    initial_state.delete('approval')
    initial_state.delete('share')
    
    setting.update!(
      state_current: { value: current_state },
      state_initial: { value: initial_state }
    )
  end
end
