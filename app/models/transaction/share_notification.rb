# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Transaction::ShareNotification
  include ChecksHumanChanges

  # Following SMTP error codes will be handled gracefully.
  # They will be logged at info level only and the code will not propagate up the error.
  # Other SMTP error codes will stop processing and exit with logging it at error level.
  #
  # 4xx - temporary issues.
  # 52x - permanent receiving server errors.
  # 55x - permanent receiving mailbox errors.
  SILENCABLE_SMTP_ERROR_CODES = [400..499, 520..529, 550..559].freeze

=begin
  {
    object: 'TicketShare',
    type: 'create|update|revoke|delete',
    object_id: 123,
    interface_handle: 'application_server', # application_server|websocket|scheduler
    changes: {
      'status' => [before, now],
    },
    created_at: Time.zone.now,
    user_id: 123,
  },
=end

  attr_accessor :recipients_and_channels, :recipients_reason

  def initialize(item, params = {})
    @item                    = item
    @params                  = params
    @recipients_and_channels = []
    @recipients_reason       = {}
  end

  def share
    # For delete operations, record is already destroyed, use data from event
    if @item[:type] == 'delete' && @item[:data]
      @share ||= OpenStruct.new(@item[:data])
    else
      @share ||= Ticket::Share.find_by(id: @item[:object_id])
    end
  end

  def ticket
    # For delete operations, get ticket from data
    if @item[:type] == 'delete' && @item[:data] && @item[:data][:ticket_id]
      @ticket ||= Ticket.find_by(id: @item[:data][:ticket_id])
    else
      @ticket ||= share&.ticket
    end
  end

  def current_user
    @current_user ||= ::User.lookup(id: @item[:user_id]) || ::User.lookup(id: 1)
  end

  def perform
    # Only process Ticket::Share objects
    if @item[:object] != 'Ticket::Share'
      Rails.logger.debug "[SHARE_NOTIFICATION] Skipping - not a Ticket::Share object: #{@item[:object]}"
      return
    end
    
    Rails.logger.info "[SHARE_NOTIFICATION] Processing share notification for #{@item[:type]} event"
    
    
    # return if we run import mode
    if Setting.get('import_mode')
      return
    end
    
    if share.blank? || ticket.blank?
      return
    end
    
    if @params[:disable_notification]
      return
    end
    
    if @params[:send_notification] == false
      return
    end
    
    # Detect actual action type from changes for update events
    # This allows us to distinguish between normal updates vs revoke actions
    if @item[:type] == 'update' && @item[:changes] && @item[:changes]['status']
      old_status, new_status = @item[:changes]['status']
      if old_status == 'active' && new_status == 'revoked'
        @item[:type] = 'revoke'
      end
    end

    prepare_recipients_and_reasons

    # send notifications
    recipients_and_channels.each do |recipient_settings|
      send_to_single_recipient(recipient_settings)
    end

    true
  end

  def prepare_recipients_and_reasons
    # get recipients based on share type
    possible_recipients = get_recipients

    # apply notification settings filter
    recipients_reason_by_notifications_settings(possible_recipients)
  end

  def get_recipients
    recipients = []

    # Get group_id - for DELETE events, it's in the serialized data
    group_id = share.group_id
    
    # Get only users who are EXPLICITLY assigned to this specific group
    # This prevents admin users with global access from being included
    # Optimized: Use joins to filter agents directly in the database query
    agent_users = ::User.joins('INNER JOIN groups_users ON groups_users.user_id = users.id')
                       .joins('INNER JOIN roles_users ON roles_users.user_id = users.id')
                       .joins('INNER JOIN roles ON roles.id = roles_users.role_id')
                       .joins('INNER JOIN permissions_roles ON permissions_roles.role_id = roles.id')
                       .joins('INNER JOIN permissions ON permissions.id = permissions_roles.permission_id')
                       .where('groups_users.group_id = ?', group_id)
                       .where("groups_users.access IN ('read', 'full')")
                       .where(active: true)
                       .where(permissions: { name: 'ticket.agent' })
                       .distinct
    
    agent_users.each do |user|
      recipients << user
    end

    # ALWAYS add the user who shared the ticket (even if they're the current user)
    # This ensures the sharer gets confirmation emails for all their share actions
    # For DELETE events, shared_by is a string, so we need to look up by ID
    
    if share.shared_by_id.present?
      sharer = ::User.find_by(id: share.shared_by_id)
      if sharer&.active? && sharer.permissions?('ticket.agent')
        recipients << sharer
      else
      end
    else
    end


    # Remove duplicates but DON'T exclude current user - they should get notification too
    recipients.compact.uniq
  rescue => e
    Rails.logger.warn "Failed to get share recipients: #{e.message}"
    Rails.logger.warn e.backtrace.first(5).join("\n")
    []
  end

  def recipients_reason_by_notifications_settings(possible_recipients)
    already_checked_recipient_ids = {}
    possible_recipients.each do |user|
      # Use 'share' as the notification type (not the action type)
      # This matches the user's notification preferences matrix
      result = NotificationFactory::Mailer.notification_settings(user, ticket, 'share')
      
      
      next if !result
      next if already_checked_recipient_ids[user.id]

      already_checked_recipient_ids[user.id] = true
      @recipients_and_channels.push result
      next if recipients_reason[user.id]

      @recipients_reason[user.id] = get_reason_for_user(user)
    end
  end

  def send_to_single_recipient(recipient_settings)
    user     = recipient_settings[:user]
    channels = recipient_settings[:channels]


    # NOTE: We want ALL group members AND the sharer to get emails for ALL actions
    # So we don't skip the person who performed the action
    # if recipient_myself?(user)
    #   return
    # end

    # ignore inactive users
    if !user.active?
      return
    end

    # NOTE: We do NOT check "already notified today" for share notifications
    # Every share action (create, update, revoke, delete) should send a notification
    # This is different from regular ticket notifications where deduplication is desired

    blocked_in_days = user.mail_delivery_failed_blocked_days
    if blocked_in_days.positive?
      return
    end

    # NOTE: Online notifications are handled by ChecksClientNotification (WebSocket broadcasts)
    # This backend is ONLY responsible for EMAIL notifications
    used_channels = []

    # ignore email channel notification and empty emails
    if !channels['email']
      add_recipient_list_to_history(ticket, user, used_channels, @item[:type])
      return
    end
    
    if user.email.blank?
      add_recipient_list_to_history(ticket, user, used_channels, @item[:type])
      return
    end

    used_channels.push 'email'
    add_recipient_list_to_history(ticket, user, used_channels, @item[:type])

    # send email notification
    # For DELETE events, group/shared_by might be strings, not objects
    group_info = share.group.respond_to?(:name) ? share.group.name : (share.group_name || share.group.to_s)
    shared_by_info = share.shared_by.respond_to?(:email) ? share.shared_by.email : (share.shared_by_name || share.shared_by.to_s)
    
    # Log the objects being passed to the template
    template_objects = build_objects(user)
    
    result = NotificationFactory::Mailer.notification(
      template:    'ticket_share_notification',
      user:        user,
      objects:     template_objects,
      message_id:  "<share.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
      references:  ticket.get_references,
      main_object: ticket,
    )
    
    
    # Log the actual email content - extract from Mail::Message object
    begin
      if result.respond_to?(:body)
        # Extract body from Mail::Message
        if result.multipart?
          # Get text/plain part if multipart
          text_part = result.text_part
          html_part = result.html_part
          if text_part
          end
          if html_part
            html_body = html_part.body.decoded
          end
        else
          # Single part message
        end
      else
      end
    rescue => e
      Rails.logger.error "[SHARE_NOTIFICATION]    Failed to extract body: #{e.message}"
    end
  rescue Channel::DeliveryError => e
    status_code = begin
      e.original_error.response.status.to_i
    rescue
      raise e
    end

    if SILENCABLE_SMTP_ERROR_CODES.any? { |elem| elem.include? status_code }
      Rails.logger.info do
        "could not send share email notification to agent (#{@item[:type]}/#{ticket.id}/#{user.email}) #{e.original_error}"
      end
      return
    end

    Rails.logger.error "[SHARE_NOTIFICATION] ❌ Email delivery failed (critical error)"
    Rails.logger.error "[SHARE_NOTIFICATION]    Error: #{e.message}"
    raise e
  rescue StandardError => e
    Rails.logger.error "[SHARE_NOTIFICATION] ❌ Unexpected error sending email to #{user.email}"
    Rails.logger.error "[SHARE_NOTIFICATION]    Error class: #{e.class.name}"
    Rails.logger.error "[SHARE_NOTIFICATION]    Error message: #{e.message}"
    Rails.logger.error "[SHARE_NOTIFICATION]    Backtrace: #{e.backtrace.first(5).join("\n")}"
    raise e
  end

  def recipient_myself?(user)
    return false if @params[:interface_handle] != 'application_server'
    return true if @item[:user_id] == user.id

    false
  end

  def add_recipient_list_to_history(ticket, user, channels, type)
    return if channels.blank?

    identifier     = user.email.presence || user.login
    recipient_list = "#{identifier}(#{type}:#{channels.join(',')})"

    ::History.add(
      o_id:           ticket.id,
      history_type:   'notification',
      history_object: 'Ticket',
      value_to:       recipient_list,
      created_by_id:  @item[:user_id] || 1
    )
  end

  def get_reason_for_user(user)
    case @item[:type]
    when 'create'
      __('You are receiving this because a ticket was shared with your group.')
    when 'update'
      __('You are receiving this because the share was updated.')
    when 'revoke'
      __('You are receiving this because the share was revoked.')
    when 'delete'
      __('You are receiving this because the share was deleted.')
    else
      __('You are receiving this because of a ticket share notification.')
    end
  end

  def build_objects(user)
    # Ensure share object has associations loaded for template
    share_obj = share
    if share_obj.respond_to?(:group) && !share_obj.association(:group).loaded?
      share_obj = Ticket::Share.includes(:group, :shared_by).find(share_obj.id)
    end
    
    # Get the user who shared the ticket
    shared_by_user = share_obj.shared_by
    
    objects = {
      ticket:        ticket,
      share:         share_obj,
      shared_by:     shared_by_user,
      shared_by_name: shared_by_user&.fullname || shared_by_user&.email || 'Unknown User',
      group_name:    share_obj.group&.name || 'Unknown Group',
      expires_at_formatted: share_obj.expires_at&.strftime('%Y-%m-%d') || 'No expiry',
      recipient:     user,
      current_user:  current_user,
      changes:       human_changes(@item[:changes], ticket, user),
      reason:        recipients_reason[user.id],
      action:        @item[:type].to_s,
      url:           ticket_url
    }
    
    if @item[:user_id]
      objects[:actor] = ::User.find(@item[:user_id])
    end
    
    objects
  end

  def ticket_url
    "#{Setting.get('http_type')}://#{Setting.get('fqdn')}/#/ticket/zoom/#{ticket.id}"
  end

  def get_notification_type
    case @item[:type]
    when 'create'
      'Ticket shared with your group'
    when 'update'
      'Share updated'
    when 'revoke'
      'Share revoked'
    when 'delete'
      'Share deleted'
    else
      'Ticket share notification'
    end
  end
end

