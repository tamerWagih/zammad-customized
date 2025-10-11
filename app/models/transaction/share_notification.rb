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
    Rails.logger.info "[SHARE_NOTIFICATION] 🔄 Backend perform() called for #{@item[:type]} on #{@item[:object]} ##{@item[:object_id]}"
    
    # Only process Ticket::Share objects
    if @item[:object] != 'Ticket::Share'
      Rails.logger.info "[SHARE_NOTIFICATION] ⏭️  Skipped: object type is #{@item[:object]}, not Ticket::Share"
      return
    end
    
    # return if we run import mode
    if Setting.get('import_mode')
      Rails.logger.info "[SHARE_NOTIFICATION] ⏭️  Skipped: import_mode enabled"
      return
    end
    
    if share.blank? || ticket.blank?
      Rails.logger.warn "[SHARE_NOTIFICATION] ⚠️  Skipped: share or ticket not found (share: #{share.inspect}, ticket: #{ticket.inspect})"
      return
    end
    
    if @params[:disable_notification]
      Rails.logger.info "[SHARE_NOTIFICATION] ⏭️  Skipped: disable_notification param"
      return
    end
    
    if @params[:send_notification] == false
      Rails.logger.info "[SHARE_NOTIFICATION] ⏭️  Skipped: send_notification=false param"
      return
    end

    prepare_recipients_and_reasons
    Rails.logger.info "[SHARE_NOTIFICATION] 📬 Recipients prepared: #{recipients_and_channels.count} recipient(s)"

    # send notifications
    recipients_and_channels.each do |recipient_settings|
      send_to_single_recipient(recipient_settings)
    end

    Rails.logger.info "[SHARE_NOTIFICATION] ✅ Backend perform() completed for share ##{@item[:object_id]}"
    true
  end

  def prepare_recipients_and_reasons
    # get recipients based on share type
    possible_recipients = get_recipients
    Rails.logger.info "[SHARE_NOTIFICATION] 📋 Possible recipients (before settings filter): #{possible_recipients.map(&:email).join(', ')}"

    # apply notification settings filter
    recipients_reason_by_notifications_settings(possible_recipients)
    Rails.logger.info "[SHARE_NOTIFICATION] 📋 Final recipients (after settings filter): #{@recipients_and_channels.map { |r| r[:user].email }.join(', ')}"
    Rails.logger.info "[SHARE_NOTIFICATION] 📋 Channels for each: #{@recipients_and_channels.map { |r| "#{r[:user].email}=#{r[:channels].inspect}" }.join(', ')}"
  end

  def get_recipients
    recipients = []

    # Get group_id - for DELETE events, it's in the serialized data
    group_id = share.group_id
    Rails.logger.info "[SHARE_NOTIFICATION] 🎯 Target group ID: #{group_id}"
    
    # Get only users who are EXPLICITLY assigned to this specific group
    # This prevents admin users with global access from being included
    group_users = ::User.joins(:user_groups)
                       .where(user_groups: { group_id: group_id, access: ['read', 'full'] })
                       .where(active: true)
    Rails.logger.info "[SHARE_NOTIFICATION] 👥 Group users (explicitly assigned): #{group_users.map { |u| "#{u.email}(#{u.id})" }.join(', ')}"
    
    agent_users = group_users.select { |user| user.permissions?('ticket.agent') }
    Rails.logger.info "[SHARE_NOTIFICATION] 👮 Agent users in group: #{agent_users.map { |u| "#{u.email}(#{u.id})" }.join(', ')}"
    
    agent_users.each do |user|
      recipients << user
    end

    # ALWAYS add the user who shared the ticket (even if they're the current user)
    # This ensures the sharer gets confirmation emails for all their share actions
    # For DELETE events, shared_by is a string, so we need to look up by ID
    Rails.logger.info "[SHARE_NOTIFICATION] 🔍 Debug - Action user: #{@item[:user_id]}, Share shared_by_id: #{share.shared_by_id}"
    
    if share.shared_by_id.present?
      sharer = ::User.find_by(id: share.shared_by_id)
      if sharer&.active? && sharer.permissions?('ticket.agent')
        recipients << sharer
        Rails.logger.info "[SHARE_NOTIFICATION] 📤 Added sharer: #{sharer.email}(#{sharer.id})"
      else
        Rails.logger.info "[SHARE_NOTIFICATION] ⏭️  Sharer not eligible: #{sharer&.email}(#{sharer&.id}) - active: #{sharer&.active?}, agent: #{sharer&.permissions?('ticket.agent')}"
      end
    else
      Rails.logger.warn "[SHARE_NOTIFICATION] ⚠️  No shared_by_id found in share object"
    end

    Rails.logger.info "[SHARE_NOTIFICATION] 📋 Action: #{@item[:type]} - Final recipients: #{recipients.map { |u| "#{u.email}(#{u.id})" }.join(', ')}"

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
      
      Rails.logger.info "[SHARE_NOTIFICATION] 🔍 Notification settings check for #{user.email}: #{result ? 'PASSED' : 'FILTERED OUT'}"
      Rails.logger.info "[SHARE_NOTIFICATION]    Settings result: #{result.inspect}" if result
      
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

    Rails.logger.info "[SHARE_NOTIFICATION] 👤 Processing recipient: #{user.email} (channels: #{channels.keys.join(', ')})"

    # NOTE: We want ALL group members AND the sharer to get emails for ALL actions
    # So we don't skip the person who performed the action
    # if recipient_myself?(user)
    #   Rails.logger.info "[SHARE_NOTIFICATION] ⏭️  Skipped #{user.email}: recipient is sender (myself)"
    #   return
    # end

    # ignore inactive users
    if !user.active?
      Rails.logger.info "[SHARE_NOTIFICATION] ⏭️  Skipped #{user.email}: user inactive"
      return
    end

    # NOTE: We do NOT check "already notified today" for share notifications
    # Every share action (create, update, revoke, delete) should send a notification
    # This is different from regular ticket notifications where deduplication is desired

    blocked_in_days = user.mail_delivery_failed_blocked_days
    if blocked_in_days.positive?
      Rails.logger.info "[SHARE_NOTIFICATION] ⏭️  Skipped #{user.email}: email marked as mail_delivery_failed for #{blocked_in_days} day(s)"
      return
    end

    # NOTE: Online notifications are handled by ChecksClientNotification (WebSocket broadcasts)
    # This backend is ONLY responsible for EMAIL notifications
    used_channels = []
    Rails.logger.info "[SHARE_NOTIFICATION] 📋 Channels for #{user.email}: #{channels.inspect}"

    # ignore email channel notification and empty emails
    if !channels['email']
      Rails.logger.info "[SHARE_NOTIFICATION] ⏭️  Email skipped for #{user.email}: email channel not enabled"
      add_recipient_list_to_history(ticket, user, used_channels, @item[:type])
      return
    end
    
    if user.email.blank?
      Rails.logger.warn "[SHARE_NOTIFICATION] ⚠️  Email skipped for user: no email address"
      add_recipient_list_to_history(ticket, user, used_channels, @item[:type])
      return
    end

    used_channels.push 'email'
    add_recipient_list_to_history(ticket, user, used_channels, @item[:type])

    # send email notification
    Rails.logger.info "[SHARE_NOTIFICATION] 📧 Sending email to #{user.email}"
    Rails.logger.info "[SHARE_NOTIFICATION]    Template: ticket_share_notification"
    Rails.logger.info "[SHARE_NOTIFICATION]    Action: #{@item[:type]}"
    Rails.logger.info "[SHARE_NOTIFICATION]    Ticket: ##{ticket.id} (#{ticket.title})"
    Rails.logger.info "[SHARE_NOTIFICATION]    Share: ##{share.id} (status: #{share.status})"
    # For DELETE events, group/shared_by might be strings, not objects
    group_info = share.group.respond_to?(:name) ? share.group.name : (share.group_name || share.group.to_s)
    shared_by_info = share.shared_by.respond_to?(:email) ? share.shared_by.email : (share.shared_by_name || share.shared_by.to_s)
    Rails.logger.info "[SHARE_NOTIFICATION]    Group: #{group_info}"
    Rails.logger.info "[SHARE_NOTIFICATION]    Shared by: #{shared_by_info}"
    
    # Log the objects being passed to the template
    template_objects = build_objects(user)
    Rails.logger.info "[SHARE_NOTIFICATION] 📧 Email template objects for #{user.email}:"
    Rails.logger.info "[SHARE_NOTIFICATION]    Share ID: #{template_objects[:share]&.id}"
    Rails.logger.info "[SHARE_NOTIFICATION]    Share Group: #{template_objects[:share]&.group&.name || 'N/A'}"
    Rails.logger.info "[SHARE_NOTIFICATION]    Share Shared By: #{template_objects[:share]&.shared_by&.email || 'N/A'}"
    Rails.logger.info "[SHARE_NOTIFICATION]    Action: #{template_objects[:action]}"
    Rails.logger.info "[SHARE_NOTIFICATION]    Recipient ID: #{template_objects[:recipient]&.id}"
    
    result = NotificationFactory::Mailer.notification(
      template:    'ticket_share_notification',
      user:        user,
      objects:     template_objects,
      message_id:  "<share.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
      references:  ticket.get_references,
      main_object: ticket,
    )
    
    Rails.logger.info "[SHARE_NOTIFICATION] ✅ Email sent successfully to #{user.email}"
    Rails.logger.info "[SHARE_NOTIFICATION]    Subject: #{result[:subject] rescue 'N/A'}"
    Rails.logger.info "[SHARE_NOTIFICATION]    From: #{Setting.get('notification_sender')}"
    Rails.logger.info "[SHARE_NOTIFICATION]    Message ID: #{result[:message_id] rescue 'N/A'}"
    
    # Log the actual email content
    Rails.logger.info "[SHARE_NOTIFICATION] 📧 EMAIL CONTENT for #{user.email}:"
    Rails.logger.info "[SHARE_NOTIFICATION]    =========================================="
    Rails.logger.info "[SHARE_NOTIFICATION]    #{result[:body] rescue 'N/A'}"
    Rails.logger.info "[SHARE_NOTIFICATION]    =========================================="
  rescue Channel::DeliveryError => e
    status_code = begin
      e.original_error.response.status.to_i
    rescue
      raise e
    end

    if SILENCABLE_SMTP_ERROR_CODES.any? { |elem| elem.include? status_code }
      Rails.logger.info "[SHARE_NOTIFICATION] ⚠️  Email delivery failed (silenced SMTP error)"
      Rails.logger.info "[SHARE_NOTIFICATION]    Status code: #{status_code}"
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
    
    objects = {
      ticket:       ticket,
      share:        share_obj,
      recipient:    user,
      current_user: current_user,
      changes:      human_changes(@item[:changes], ticket, user),
      reason:       recipients_reason[user.id],
      action:       @item[:type].to_s,
      url:          ticket_url
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

