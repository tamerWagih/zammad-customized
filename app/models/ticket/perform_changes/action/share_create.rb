# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::PerformChanges::Action::ShareCreate < Ticket::PerformChanges::Action

  def self.phase
    :after_save
  end

  def execute(...)
    Rails.logger.info "[SHARE_CREATE_TRIGGER] Executing share creation trigger for ticket ##{record.id}"
    create_share(execution_data)
  end

  private

  def create_share(share_data)
    # Extract share parameters
    group_id = share_data['group_id'] || share_data[:group_id]
    expires_at = share_data['expires_at'] || share_data[:expires_at]
    
    # Log the ticket context (for debugging)
    Rails.logger.info { "Creating share for ticket ##{record.id} (#{record.title}) via trigger" }
    
    # Support both group_id and group name formats
    if group_id.is_a?(String) && group_id !~ /^\d+$/
      # It's a group name, find the group
      group = Group.find_by(name: group_id)
      group_id = group&.id
    end
    
    return if group_id.blank?

    # Get the sharing user (current user or default to system)
    shared_by_id = user_id || 1

    # Parse expiry date if provided (set to end of day)
    if expires_at.present?
      if expires_at.is_a?(String) && expires_at !~ /^\s*$/
        begin
          # Parse the date and set to end of day (23:59:59)
          parsed_date = Date.parse(expires_at)
          expires_at = parsed_date.end_of_day
        rescue ArgumentError
          Rails.logger.warn "Invalid expires_at date format: #{expires_at}"
          expires_at = nil
        end
      elsif expires_at.respond_to?(:end_of_day)
        # If it's already a date/time object, set to end of day
        expires_at = expires_at.to_date.end_of_day
      end
    else
      # Explicitly set to nil if blank/empty
      expires_at = nil
    end

    # Verify the group exists
    unless Group.exists?(group_id)
      Rails.logger.warn "Share trigger: Group with ID #{group_id} does not exist for ticket #{record.id}"
      return
    end

    # Create the share
    share = Ticket::Share.new(
      ticket_id:     record.id,
      group_id:      group_id.to_i,
      shared_by_id:  shared_by_id,
      permissions:   ['full'],
      status:        'active',
      expires_at:    expires_at,
      created_by_id: user_id || 1,
      updated_by_id: user_id || 1,
    )

        if share.save
          expiry_info = expires_at ? " (expires: #{expires_at.strftime('%Y-%m-%d %H:%M:%S')})" : " (no expiry)"
          Rails.logger.info { "Created share ##{share.id} for ticket #{record.id} with group #{group_id}#{expiry_info} via trigger" }
          
          # Add online notifications for all group members (same as original share creation)
          begin
            group = Group.find(group_id)
            # Get all active agents in the group
            group.users.where(active: true).each do |group_user|
              # Skip if the sharer is the same as the recipient (they already know they shared it)
              next if group_user.id == shared_by_id
              
              # Only notify if user has ticket.agent permission
              next unless group_user.permissions?('ticket.agent')
              
              OnlineNotification.add(
                type:          'Ticket shared with your group',
                object:        'Ticket',
                o_id:          record.id,
                seen:          false,
                user_id:       group_user.id,
                created_by_id: shared_by_id,
              )
            end
            Rails.logger.info { "Created online notifications for group #{group.name} members" }
          rescue StandardError => e
            Rails.logger.warn { "Failed to create online notifications for group members: #{e.message}" }
          end
        else
          Rails.logger.error { "Failed to create share for ticket #{record.id}: #{share.errors.full_messages.join(', ')}" }
        end
  end
end

