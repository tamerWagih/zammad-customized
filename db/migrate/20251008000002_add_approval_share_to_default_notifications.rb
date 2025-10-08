# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddApprovalShareToDefaultNotifications < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup
    return if !Setting.exists?(name: 'system_init_done')

    # Get the current setting
    setting = Setting.find_by(name: 'ticket_agent_default_notifications')
    return if !setting

    # Get current state
    current_state = setting.state || {}
    
    # Add approval and share notification types if they don't exist
    unless current_state['approval']
      current_state['approval'] = {
        criteria: {
          owned_by_me:     true,
          owned_by_nobody: true,
          subscribed:      true,
          no:              false,
        },
        channel:  {
          email:  true,
          online: true,
        }
      }
    end

    unless current_state['share']
      current_state['share'] = {
        criteria: {
          owned_by_me:     true,
          owned_by_nobody: true,
          subscribed:      true,
          no:              false,
        },
        channel:  {
          email:  true,
          online: true,
        }
      }
    end

    # Update the setting
    setting.update!(state: current_state)
    
    # CRITICAL: Also update the initial state so "Reset to default" works correctly
    # The initial state is what gets restored when users click "Reset to default"
    setting.update!(state_initial: current_state)
  end

  def down
    # Remove approval and share from the setting
    setting = Setting.find_by(name: 'ticket_agent_default_notifications')
    return if !setting

    current_state = setting.state || {}
    current_state.delete('approval')
    current_state.delete('share')
    
    setting.update!(state: current_state)
  end
end
