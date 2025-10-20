# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Transaction::CcNotification
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
    object: 'Ticket::Cc',
    type: 'create|update|delete',
    object_id: 123,
    interface_handle: 'application_server', # application_server|websocket|scheduler
    changes: {
      'permissions' => [before, now],
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

  def cc_record
    # For delete operations, record is already destroyed, use data from event
    if @item[:type] == 'delete' && @item[:data]
      @cc_record ||= OpenStruct.new(@item[:data])
    else
      @cc_record ||= Ticket::Cc.find_by(id: @item[:object_id])
    end
  end

  def ticket
    # For delete operations, get ticket from data
    if @item[:type] == 'delete' && @item[:data] && @item[:data][:ticket_id]
      @ticket ||= Ticket.find_by(id: @item[:data][:ticket_id])
    else
      @ticket ||= cc_record&.ticket
    end
  end

  def current_user
    @current_user ||= ::User.lookup(id: @item[:user_id]) || ::User.lookup(id: 1)
  end

  def perform
    # Only process Ticket::Cc objects
    if @item[:object] != 'Ticket::Cc'
      return
    end
    
    # return if we run import mode
    if Setting.get('import_mode')
      return
    end
    
    if cc_record.blank? || ticket.blank?
      return
    end
    
    if @params[:disable_notification]
      return
    end
    
    if @params[:send_notification] == false
      return
    end
    
    prepare_recipients_and_reasons

    # send notifications
    recipients_and_channels.each do |recipient_settings|
      send_to_single_recipient(recipient_settings)
    end

    true
  end

  def prepare_recipients_and_reasons
    # get recipients based on CC type
    possible_recipients = get_recipients

    # apply notification settings filter
    recipients_reason_by_notifications_settings(possible_recipients)
  end

  def get_recipients
    recipients = []

    # ALWAYS send to BOTH CC user and creator for ALL actions
    # This ensures both parties stay informed about any changes
    
    if cc_record.user_id.present?
      cc_user = ::User.find_by(id: cc_record.user_id)
      recipients << cc_user if cc_user
    end
    
    if cc_record.created_by_id.present?
      creator_user = ::User.find_by(id: cc_record.created_by_id)
      recipients << creator_user if creator_user
    end

    # Remove duplicates but DON'T exclude current user - they should get notification too
    recipients.compact.uniq
  end

  def recipients_reason_by_notifications_settings(possible_recipients)
    already_checked_recipient_ids = {}
    possible_recipients.each do |user|
      # Use 'cc' as the notification type
      # This matches the user's notification preferences matrix
      result = NotificationFactory::Mailer.notification_settings(user, ticket, 'cc')
      
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

    # NOTE: We want BOTH CC user and creator to get emails for ALL actions
    # So we don't skip the person who performed the action

    # ignore inactive users
    if !user.active?
      return
    end

    # NOTE: We do NOT check "already notified today" for CC notifications
    # Every CC action (create, update, delete) should send a notification
    # This is different from regular ticket notifications where deduplication is desired

    blocked_in_days = user.mail_delivery_failed_blocked_days
    if blocked_in_days.positive?
      Rails.logger.info "Send no CC notifications to #{user.email} because email is marked as mail_delivery_failed for #{blocked_in_days} day(s)"
      return
    end

    # NOTE: Online notifications are handled by the controller's notify_user method
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
    
    # Log the objects being passed to the template
    template_objects = build_objects(user)
    
    result = NotificationFactory::Mailer.notification(
      template:    'ticket_cc_notification',
      user:        user,
      objects:     template_objects,
      message_id:  "<cc.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
      references:  ticket.get_references,
      main_object: ticket,
    )
    
    # Log the actual email content - extract from Mail::Message object
    begin
      if result.is_a?(Mail::Message)
        Rails.logger.debug { "CC EMAIL sent successfully to #{user.email}" }
      end
    rescue => e
      Rails.logger.error "Failed to log CC email result: #{e.message}"
    end
  rescue Net::SMTPAuthenticationError, Net::SMTPServerBusy, Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError, Errno::ECONNREFUSED, Timeout::Error => e
    status_code = e.respond_to?(:status_code) ? e.status_code : 0
    original_error = e.respond_to?(:original_error) ? e.original_error : e
    
    begin
      if e.is_a?(Net::SMTPFatalError) && e.message.include?('5.7.1')
        raise e
      end
    rescue StandardError => e
      Rails.logger.error "Error checking SMTP status code: #{e.message}"
      raise e
    end

    if SILENCABLE_SMTP_ERROR_CODES.any? { |elem| elem.include? status_code }
      Rails.logger.info do
        "could not send CC email notification to user (#{@item[:type]}/#{ticket.id}/#{user.email}) #{original_error}"
      end
      return
    end

    Rails.logger.error "could not send CC email notification to user (#{@item[:type]}/#{ticket.id}/#{user.email})"
    
    raise e
  rescue StandardError => e
    Rails.logger.error e
    raise e
  end

  def add_recipient_list_to_history(ticket, user, channels, type)
    return if @item[:article_id].present?
    return if channels.blank?

    ticket.history_log(
      'notification',
      user.id,
      history_type:       type,
      value_from:         user.email,
      value_to:           channels.join(', '),
      created_by_id:      current_user.id || 1,
      not_change_updated: true
    )
  end

  def get_reason_for_user(user)
    case @item[:type]
    when 'create'
      if user.id == cc_record.user_id
        __('You are receiving this because you were CC\'d on this ticket.')
      else
        __('You are receiving this because you CC\'d someone on this ticket.')
      end
    when 'delete'
      if user.id == cc_record.user_id
        __('You are receiving this because you were removed from CC on this ticket.')
      else
        __('You are receiving this because you removed someone from CC on this ticket.')
      end
    else
      __('You are receiving this because of a CC notification.')
    end
  end

  def build_objects(user)
    # Ensure CC object has associations loaded for template
    cc_obj = cc_record
    
    # Get CC user and creator
    cc_user = nil
    creator = nil
    
    # Handle both active record objects and OpenStruct (for delete operations)
    user_id = cc_obj.respond_to?(:user_id) ? cc_obj.user_id : cc_obj[:user_id]
    created_by_id = cc_obj.respond_to?(:created_by_id) ? cc_obj.created_by_id : cc_obj[:created_by_id]
    
    if user_id
      cc_user = ::User.find_by(id: user_id)
    end
    
    if created_by_id
      creator = ::User.find_by(id: created_by_id)
    end
    
    # Get user_id for comparison (handle both AR and OpenStruct)
    cc_user_id = cc_obj.respond_to?(:user_id) ? cc_obj.user_id : (cc_obj[:user_id] || user_id)
    
    # Build comprehensive objects hash for email template
    {
      ticket:        ticket,
      cc:            cc_obj,
      recipient:     user,
      current_user:  current_user,
      changes:       @item[:changes] || {},
      reason:        recipients_reason[user.id] || get_reason_for_user(user),
      action:        @item[:type],
      cc_user:       cc_user,
      creator:       creator,
      cc_user_name:  cc_user&.fullname || 'Unknown User',
      creator_name:  creator&.fullname || 'Unknown User',
    }
  end
end