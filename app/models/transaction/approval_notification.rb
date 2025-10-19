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
    # Only process Ticket::Approval objects
    if @item[:object] != 'Ticket::Approval'
      Rails.logger.debug "[APPROVAL_NOTIFICATION] Skipping - not a Ticket::Approval object: #{@item[:object]}"
      return
    end
    
    Rails.logger.info "[APPROVAL_NOTIFICATION] Processing approval notification for #{@item[:type]} event"
    
    # return if we run import mode
    if Setting.get('import_mode')
      return
    end
    
    if approval.blank? || ticket.blank?
      return
    end
    
    if @params[:disable_notification]
      return
    end
    
    if @params[:send_notification] == false
      return
    end
    
    # Detect actual action type from changes for update events
    # This allows us to distinguish between normal updates vs approve/reject actions
    if @item[:type] == 'update' && @item[:changes] && @item[:changes]['status']
      old_status, new_status = @item[:changes]['status']
      if old_status == 'pending' && new_status == 'approved'
        @item[:type] = 'approve'
      elsif old_status == 'pending' && new_status == 'rejected'
        @item[:type] = 'reject'
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
    # get recipients based on approval type
    possible_recipients = get_recipients

    # apply notification settings filter
    recipients_reason_by_notifications_settings(possible_recipients)
  end

  def get_recipients
    recipients = []

    # ALWAYS send to BOTH approver and requester for ALL actions
    # This ensures both parties stay informed about any changes
    # For DELETE events, approver/requester are strings, so we need to look up by ID
    
    if approval.approver_id.present?
      approver_user = ::User.find_by(id: approval.approver_id)
      if approver_user
        recipients << approver_user
      else
      end
    end
    
    if approval.requester_id.present?
      requester_user = ::User.find_by(id: approval.requester_id)
      if requester_user
        recipients << requester_user
      else
      end
    end


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


    # NOTE: We want BOTH approver and requester to get emails for ALL actions
    # So we don't skip the person who performed the action

    # ignore inactive users
    if !user.active?
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
    # For DELETE events, approver/requester are strings, not User objects
    approver_info = approval.approver.respond_to?(:email) ? approval.approver.email : approval.approver.to_s
    requester_info = approval.requester.respond_to?(:email) ? approval.requester.email : approval.requester.to_s
    
    # Log the objects being passed to the template
    template_objects = build_objects(user)
    
    result = NotificationFactory::Mailer.notification(
      template:    'ticket_approval_notification',
      user:        user,
      objects:     template_objects,
      message_id:  "<approval.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
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
      Rails.logger.error "[APPROVAL_NOTIFICATION]    Failed to extract body: #{e.message}"
    end
  rescue Channel::DeliveryError => e
    status_code = begin
      e.original_error.response.status.to_i
    rescue
      raise e
    end

    if SILENCABLE_SMTP_ERROR_CODES.any? { |elem| elem.include? status_code }
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
    # Ensure approval object has associations loaded for template
    approval_obj = approval
    
    # Get approver and requester - handle both User objects and strings
    approver_user = nil
    requester_user = nil
    
    begin
      # Try to get approver from association
      approver_user = approval_obj.approver
      
      # If it's a string or not a User object, try to find the User by ID
      if !approver_user.is_a?(User)
        if approval_obj.respond_to?(:approver_id) && approval_obj.approver_id.present?
          approver_user = User.find_by(id: approval_obj.approver_id)
        end
      end
    rescue => e
      # Try to find by ID as fallback
      if approval_obj.respond_to?(:approver_id) && approval_obj.approver_id.present?
        approver_user = User.find_by(id: approval_obj.approver_id)
      end
    end
    
    begin
      # Try to get requester from association
      requester_user = approval_obj.requester
      
      # If it's a string or not a User object, try to find the User by ID
      if !requester_user.is_a?(User)
        if approval_obj.respond_to?(:requester_id) && approval_obj.requester_id.present?
          requester_user = User.find_by(id: approval_obj.requester_id)
        end
      end
    rescue => e
      # Try to find by ID as fallback
      if approval_obj.respond_to?(:requester_id) && approval_obj.requester_id.present?
        requester_user = User.find_by(id: approval_obj.requester_id)
      end
    end
    
    objects = {
      ticket:         ticket,
      approval:       approval_obj,
      approver:       approver_user,
      requester:      requester_user,
      approver_name:  approver_user&.fullname || approver_user&.email || 'Unknown Approver',
      requester_name: requester_user&.fullname || requester_user&.email || 'Unknown Requester',
      recipient:      user,
      current_user:   current_user,
      changes:        human_changes(@item[:changes], ticket, user),
      reason:         recipients_reason[user.id],
      action:         @item[:type].to_s,
      url:            ticket_url
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

