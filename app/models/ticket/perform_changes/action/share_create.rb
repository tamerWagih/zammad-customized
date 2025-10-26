# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::PerformChanges::Action::ShareCreate < Ticket::PerformChanges::Action

  def self.phase
    :after_save
  end

  def execute(...)
    create_share(execution_data)
  end

  private

  def create_share(share_data)
    # Extract share parameters - support multiple formats:
    # 1. Single group: { 'group_id' => '123' }
    # 2. Array field: { 'group_id' => ['123', '456'] } (from +/- buttons in UI)
    # 3. Explicit array: { 'group_ids' => ['123', '456'] }
    group_ids = if share_data['group_ids'].present?
                  # Explicit array format
                  Array(share_data['group_ids'])
                elsif share_data['group_id'].present?
                  # Could be single value or array (from +/- UI buttons)
                  Array(share_data['group_id'])
                elsif share_data[:group_id].present?
                  # Symbol key fallback
                  Array(share_data[:group_id])
                else
                  []
                end
    
    # Remove empty/nil values
    group_ids = group_ids.compact.reject(&:blank?)
    
    expires_at = share_data['expires_at'] || share_data[:expires_at]
    
    # Log the ticket context (for debugging)
    Rails.logger.info { "Creating shares for ticket ##{record.id} (#{record.title}) with #{group_ids.length} group(s) via trigger" }
    
    return if group_ids.blank?

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

    # Process each group
    group_ids.each do |group_id|
      # Support both group_id and group name formats
      if group_id.is_a?(String) && group_id !~ /^\d+$/
        # It's a group name, find the group
        group = Group.find_by(name: group_id)
        group_id = group&.id
      end

      next if group_id.blank?

      # Verify the group exists
      unless Group.exists?(group_id)
        Rails.logger.warn "Share trigger: Group with ID #{group_id} does not exist for ticket #{record.id}"
        next
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
        Rails.logger.error { "Failed to create share for ticket #{record.id} with group #{group_id}: #{share.errors.full_messages.join(', ')}" }
      end
    end
  end
end

