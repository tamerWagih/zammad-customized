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
    # Extract share parameters
    group_id = share_data['group_id'] || share_data[:group_id]
    expires_at = share_data['expires_at'] || share_data[:expires_at]
    
    # Support both group_id and group name formats
    if group_id.is_a?(String) && group_id !~ /^\d+$/
      # It's a group name, find the group
      group = Group.find_by(name: group_id)
      group_id = group&.id
    end
    
    return if group_id.blank?

    # Get the sharing user (current user or default to system)
    shared_by_id = user_id || 1

    # Parse expiry date if provided as string
    if expires_at.is_a?(String)
      begin
        expires_at = Time.zone.parse(expires_at)
      rescue ArgumentError
        expires_at = nil
      end
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

    share.save!

    Rails.logger.info { "Created share for ticket #{record.id} with group #{group_id} via trigger" }
  end
end

