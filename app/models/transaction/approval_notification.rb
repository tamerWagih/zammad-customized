# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Transaction::ApprovalNotification
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
    object: 'TicketApproval',
    type: 'create|update|approve|reject|delete',
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

  def approval
    # For delete operations, record is already destroyed, use data from event
    if @item[:type] == 'delete' && @item[:data]
      @approval ||= OpenStruct.new(@item[:data])
    else
      @approval ||= Ticket::Approval.find_by(id: @item[:object_id])
    end
  end

  def ticket
    # For delete operations, get ticket from data
    if @item[:type] == 'delete' && @item[:data] && @item[:data][:ticket_id]
      @ticket ||= Ticket.find_by(id: @item[:data][:ticket_id])
    else
      @ticket ||= approval&.ticket
    end
  end

  def current_user
    @current_user ||= ::User.lookup(id: @item[:user_id]) || ::User.lookup(id: 1)
  end

  def perform
    Rails.logger.info "[APPROVAL_NOTIFICATION] 🔄 Backend perform() called for #{@item[:type]} on #{@item[:object]} ##{@item[:object_id]}"
    
    # Only process Ticket::Approval objects
    if @item[:object] != 'Ticket::Approval'
      Rails.logger.info "[APPROVAL_NOTIFICATION] ⏭️  Skipped: object type is #{@item[:object]}, not Ticket::Approval"
      return
    end
    
    # return if we run import mode
    if Setting.get('import_mode')
      Rails.logger.info "[APPROVAL_NOTIFICATION] ⏭️  Skipped: import_mode enabled"
      return
    end
    
    if approval.blank? || ticket.blank?
      Rails.logger.warn "[APPROVAL_NOTIFICATION] ⚠️  Skipped: approval or ticket not found (approval: #{approval.inspect}, ticket: #{ticket.inspect})"
      return
    end
    
    if @params[:disable_notification]
      Rails.logger.info "[APPROVAL_NOTIFICATION] ⏭️  Skipped: disable_notification param"
      return
    end
    
    if @params[:send_notification] == false
      Rails.logger.info "[APPROVAL_NOTIFICATION] ⏭️  Skipped: send_notification=false param"
      return
    end

    prepare_recipients_and_reasons
    Rails.logger.info "[APPROVAL_NOTIFICATION] 📬 Recipients prepared: #{recipients_and_channels.count} recipient(s)"

    # send notifications
    recipients_and_channels.each do |recipient_settings|
      send_to_single_recipient(recipient_settings)
    end

    Rails.logger.info "[APPROVAL_NOTIFICATION] ✅ Backend perform() completed for approval ##{@item[:object_id]}"
    true
  end

  def prepare_recipients_and_reasons
    # get recipients based on approval type
    possible_recipients = get_recipients
    Rails.logger.info "[APPROVAL_NOTIFICATION] 📋 Possible recipients (before settings filter): #{possible_recipients.map(&:email).join(', ')}"

    # apply notification settings filter
    recipients_reason_by_notifications_settings(possible_recipients)
    Rails.logger.info "[APPROVAL_NOTIFICATION] 📋 Final recipients (after settings filter): #{@recipients_and_channels.map { |r| r[:user].email }.join(', ')}"
    Rails.logger.info "[APPROVAL_NOTIFICATION] 📋 Channels for each: #{@recipients_and_channels.map { |r| "#{r[:user].email}=#{r[:channels].inspect}" }.join(', ')}"
  end

  def get_recipients
    recipients = []

    # ALWAYS send to BOTH approver and requester for ALL actions
    # This ensures both parties stay informed about any changes
    # For DELETE events, approver/requester are strings, so we need to look up by ID
    if approval.approver_id.present?
      approver_user = ::User.find_by(id: approval.approver_id)
      recipients << approver_user if approver_user
    end
    
    if approval.requester_id.present?
      requester_user = ::User.find_by(id: approval.requester_id)
      recipients << requester_user if requester_user
    end

    Rails.logger.info "[APPROVAL_NOTIFICATION] 📋 Action: #{@item[:type]} - Sending to BOTH approver and requester"

    # Remove duplicates but DON'T exclude current user - they should get notification too
    recipients.compact.uniq
  end

  def recipients_reason_by_notifications_settings(possible_recipients)
    already_checked_recipient_ids = {}
    possible_recipients.each do |user|
      # Use 'approval' as the notification type (not the action type)
      # This matches the user's notification preferences matrix
      result = NotificationFactory::Mailer.notification_settings(user, ticket, 'approval')
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

    Rails.logger.info "[APPROVAL_NOTIFICATION] 👤 Processing recipient: #{user.email} (channels: #{channels.keys.join(', ')})"

    # NOTE: We want BOTH approver and requester to get emails for ALL actions
    # So we don't skip the person who performed the action
    # if recipient_myself?(user)
    #   Rails.logger.info "[APPROVAL_NOTIFICATION] ⏭️  Skipped #{user.email}: recipient is sender (myself)"
    #   return
    # end

    # ignore inactive users
    if !user.active?
      Rails.logger.info "[APPROVAL_NOTIFICATION] ⏭️  Skipped #{user.email}: user inactive"
      return
    end

    # NOTE: We do NOT check "already notified today" for approval notifications
    # Every approval action (create, update, approve, reject, delete) should send a notification
    # This is different from regular ticket notifications where deduplication is desired

    blocked_in_days = user.mail_delivery_failed_blocked_days
    if blocked_in_days.positive?
      Rails.logger.info "Send no approval notifications to #{user.email} because email is marked as mail_delivery_failed for #{blocked_in_days} day(s)"
      return
    end

    # create online notification
    # RULES: 
    # - For create/update/delete: notify approver (receiver) only
    # - For approve/reject: notify requester (sender) only
    used_channels = []
    Rails.logger.info "[APPROVAL_NOTIFICATION] 📋 Channels for #{user.email}: #{channels.inspect}"
    
    if channels['online']
      should_send_online = false
      
      # Determine if this user should get online notification based on action
      if %w[create update delete].include?(@item[:type])
        # Notify approver (receiver) only
        should_send_online = (user.id == approval.approver_id)
        Rails.logger.info "[APPROVAL_NOTIFICATION] 📋 Online notification check (#{@item[:type]}): user=#{user.id}, approver=#{approval.approver_id}, should_send=#{should_send_online}"
      elsif %w[approve reject].include?(@item[:type])
        # Notify requester (sender) only
        should_send_online = (user.id == approval.requester_id)
        Rails.logger.info "[APPROVAL_NOTIFICATION] 📋 Online notification check (#{@item[:type]}): user=#{user.id}, requester=#{approval.requester_id}, should_send=#{should_send_online}"
      end
      
      if should_send_online
        used_channels.push 'online'

        created_by_id = @item[:user_id] || 1

        ::OnlineNotification.add(
          type:          get_notification_type,
          object:        'Ticket',
          o_id:          ticket.id,
          seen:          false,
          created_by_id: created_by_id,
          user_id:       user.id,
        )
        Rails.logger.info "[APPROVAL_NOTIFICATION] ✅ Online notification sent to #{user.email} (#{@item[:type]}/#{ticket.id})"
      else
        Rails.logger.info "[APPROVAL_NOTIFICATION] ⏭️  Online notification skipped for #{user.email}: not the target for #{@item[:type]} action"
      end
    end

    # ignore email channel notification and empty emails
    if !channels['email']
      Rails.logger.info "[APPROVAL_NOTIFICATION] ⏭️  Email skipped for #{user.email}: email channel not enabled (channels: #{channels.inspect})"
      add_recipient_list_to_history(ticket, user, used_channels, @item[:type])
      return
    end
    
    if user.email.blank?
      Rails.logger.warn "[APPROVAL_NOTIFICATION] ⚠️  Email skipped for user: no email address"
      add_recipient_list_to_history(ticket, user, used_channels, @item[:type])
      return
    end

    used_channels.push 'email'
    add_recipient_list_to_history(ticket, user, used_channels, @item[:type])

    # send email notification
    Rails.logger.info "[APPROVAL_NOTIFICATION] 📧 Sending email to #{user.email}"
    Rails.logger.info "[APPROVAL_NOTIFICATION]    Template: ticket_approval_notification"
    Rails.logger.info "[APPROVAL_NOTIFICATION]    Action: #{@item[:type]}"
    Rails.logger.info "[APPROVAL_NOTIFICATION]    Ticket: ##{ticket.id} (#{ticket.title})"
    Rails.logger.info "[APPROVAL_NOTIFICATION]    Approval: ##{approval.id} (status: #{approval.status})"
    # For DELETE events, approver/requester are strings, not User objects
    approver_info = approval.approver.respond_to?(:email) ? approval.approver.email : approval.approver.to_s
    requester_info = approval.requester.respond_to?(:email) ? approval.requester.email : approval.requester.to_s
    Rails.logger.info "[APPROVAL_NOTIFICATION]    Approver: #{approver_info}"
    Rails.logger.info "[APPROVAL_NOTIFICATION]    Requester: #{requester_info}"
    
    result = NotificationFactory::Mailer.notification(
      template:    'ticket_approval_notification',
      user:        user,
      objects:     build_objects(user),
      message_id:  "<approval.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
      references:  ticket.get_references,
      main_object: ticket,
    )
    
    Rails.logger.info "[APPROVAL_NOTIFICATION] ✅ Email sent successfully to #{user.email}"
    Rails.logger.info "[APPROVAL_NOTIFICATION]    Subject: #{result[:subject] rescue 'N/A'}"
    Rails.logger.info "[APPROVAL_NOTIFICATION]    From: #{Setting.get('notification_sender')}"
    Rails.logger.info "[APPROVAL_NOTIFICATION]    Message ID: #{result[:message_id] rescue 'N/A'}"
  rescue Channel::DeliveryError => e
    status_code = begin
      e.original_error.response.status.to_i
    rescue
      raise e
    end

    if SILENCABLE_SMTP_ERROR_CODES.any? { |elem| elem.include? status_code }
      Rails.logger.info "[APPROVAL_NOTIFICATION] ⚠️  Email delivery failed (silenced SMTP error)"
      Rails.logger.info "[APPROVAL_NOTIFICATION]    Status code: #{status_code}"
      Rails.logger.info do
        "could not send approval email notification to agent (#{@item[:type]}/#{ticket.id}/#{user.email}) #{e.original_error}"
      end
      return
    end

    Rails.logger.error "[APPROVAL_NOTIFICATION] ❌ Email delivery failed (critical error)"
    Rails.logger.error "[APPROVAL_NOTIFICATION]    Error: #{e.message}"
    raise e
  rescue StandardError => e
    Rails.logger.error "[APPROVAL_NOTIFICATION] ❌ Unexpected error sending email to #{user.email}"
    Rails.logger.error "[APPROVAL_NOTIFICATION]    Error class: #{e.class.name}"
    Rails.logger.error "[APPROVAL_NOTIFICATION]    Error message: #{e.message}"
    Rails.logger.error "[APPROVAL_NOTIFICATION]    Backtrace: #{e.backtrace.first(5).join("\n")}"
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
      if user.id == approval.approver_id
        __('You are receiving this because you are the approver for this ticket.')
      else
        __('You are receiving this because you requested approval for this ticket.')
      end
    when 'update'
      if user.id == approval.approver_id
        __('You are receiving this because the approval request was updated.')
      else
        __('You are receiving this because you updated the approval request.')
      end
    when 'approve', 'reject'
      __('You are receiving this because your approval request was responded to.')
    when 'delete'
      __('You are receiving this because the approval request was deleted.')
    else
      __('You are receiving this because of an approval notification.')
    end
  end

  def build_objects(user)
    objects = {
      ticket:       ticket,
      approval:     approval,
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
      'Approval request'
    when 'update'
      'Approval request updated'
    when 'approve'
      'Approval approved'
    when 'reject'
      'Approval rejected'
    when 'delete'
      'Approval request deleted'
    else
      'Approval notification'
    end
  end
end

