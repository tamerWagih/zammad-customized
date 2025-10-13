# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Transaction::CcNotification
  include ChecksHumanChanges
  
  # Following SMTP error codes will be handled gracefully.
  SILENCABLE_SMTP_ERROR_CODES = [400..499, 520..529, 550..559].freeze
  
  attr_accessor :recipients_and_channels, :recipients_reason
  
  def initialize(item, params = {})
    @item = item
    @params = params
    @recipients_and_channels = []
    @recipients_reason = {}
  end
  
  def cc_record
    if @item[:type] == 'delete' && @item[:data]
      @cc_record ||= OpenStruct.new(@item[:data])
    else
      @cc_record ||= Ticket::Cc.find_by(id: @item[:object_id])
    end
  end
  
  def ticket
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
    Rails.logger.info "[CC_NOTIFICATION] 🔄 Backend perform() called for #{@item[:type]} on #{@item[:object]} ##{@item[:object_id]}"
    
    # Only process Ticket::Cc objects
    if @item[:object] != 'Ticket::Cc'
      return
    end
    
    # return if we run import mode
    if Setting.get('import_mode')
      return
    end
    
    if cc_record.blank? || ticket.blank?
      Rails.logger.warn "[CC_NOTIFICATION] ⚠️  Skipped: cc_record or ticket not found"
      return
    end
    
    if @params[:disable_notification]
      Rails.logger.info "[CC_NOTIFICATION] ⏭️  Skipped: disable_notification param"
      return
    end
    
    if @params[:send_notification] == false
      Rails.logger.info "[CC_NOTIFICATION] ⏭️  Skipped: send_notification=false param"
      return
    end
    
    # Only send notifications on create
    return unless @item[:type] == 'create'
    
    prepare_recipients_and_reasons
    Rails.logger.info "[CC_NOTIFICATION] 📬 Recipients prepared: #{recipients_and_channels.count} recipient(s)"
    
    # send notifications
    recipients_and_channels.each do |recipient_settings|
      send_to_single_recipient(recipient_settings)
    end
    
    Rails.logger.info "[CC_NOTIFICATION] ✅ Backend perform() completed for CC ##{@item[:object_id]}"
    true
  end
  
  def prepare_recipients_and_reasons
    # get recipients
    possible_recipients = get_recipients
    Rails.logger.info "[CC_NOTIFICATION] 📋 Possible recipients (before settings filter): #{possible_recipients.map(&:email).join(', ')}"
    
    # apply notification settings filter
    recipients_reason_by_notifications_settings(possible_recipients)
    Rails.logger.info "[CC_NOTIFICATION] 📋 Final recipients (after settings filter): #{@recipients_and_channels.map { |r| r[:user].email }.join(', ')}"
  end
  
  def get_recipients
    recipients = []
    
    # Add the CC'd user
    cc_user = cc_record.user
    if cc_user&.active?
      recipients << cc_user
      Rails.logger.info "[CC_NOTIFICATION] 👤 Added CC'd user: #{cc_user.email}(#{cc_user.id})"
    end
    
    # Add the creator (person who added the CC) for confirmation
    creator = cc_record.created_by
    if creator&.active? && creator.id != cc_user.id
      recipients << creator
      Rails.logger.info "[CC_NOTIFICATION] 📤 Added creator: #{creator.email}(#{creator.id})"
    end
    
    Rails.logger.info "[CC_NOTIFICATION] 📋 Final recipients: #{recipients.map { |u| "#{u.email}(#{u.id})" }.join(', ')}"
    
    recipients.compact.uniq
  rescue => e
    Rails.logger.warn "Failed to get CC recipients: #{e.message}"
    Rails.logger.warn e.backtrace.first(5).join("\n")
    []
  end
  
  def recipients_reason_by_notifications_settings(possible_recipients)
    already_checked_recipient_ids = {}
    possible_recipients.each do |user|
      # Use 'cc' as the notification type
      result = NotificationFactory::Mailer.notification_settings(user, ticket, 'cc')
      
      Rails.logger.info "[CC_NOTIFICATION] 🔍 Notification settings check for #{user.email}: #{result ? 'PASSED' : 'FILTERED OUT'}"
      
      next if !result
      next if already_checked_recipient_ids[user.id]
      
      already_checked_recipient_ids[user.id] = true
      @recipients_and_channels.push result
      next if recipients_reason[user.id]
      
      @recipients_reason[user.id] = get_reason_for_user(user)
    end
  end
  
  def send_to_single_recipient(recipient_settings)
    user = recipient_settings[:user]
    channels = recipient_settings[:channels]
    
    Rails.logger.info "[CC_NOTIFICATION] 👤 Processing recipient: #{user.email} (channels: #{channels.keys.join(', ')})"
    
    # ignore inactive users
    if !user.active?
      Rails.logger.info "[CC_NOTIFICATION] ⏭️  Skipped #{user.email}: user inactive"
      return
    end
    
    blocked_in_days = user.mail_delivery_failed_blocked_days
    if blocked_in_days.positive?
      Rails.logger.info "[CC_NOTIFICATION] ⏭️  Skipped #{user.email}: email marked as mail_delivery_failed for #{blocked_in_days} day(s)"
      return
    end
    
    used_channels = []
    
    # ignore email channel notification and empty emails
    if !channels['email']
      Rails.logger.info "[CC_NOTIFICATION] ⏭️  Email skipped for #{user.email}: email channel not enabled"
      add_recipient_list_to_history(ticket, user, used_channels, 'cc')
      return
    end
    
    if user.email.blank?
      Rails.logger.warn "[CC_NOTIFICATION] ⚠️  Email skipped for user: no email address"
      add_recipient_list_to_history(ticket, user, used_channels, 'cc')
      return
    end
    
    used_channels.push 'email'
    add_recipient_list_to_history(ticket, user, used_channels, 'cc')
    
    # send email notification
    Rails.logger.info "[CC_NOTIFICATION] 📧 Sending email to #{user.email}"
    Rails.logger.info "[CC_NOTIFICATION]    Template: ticket_cc_notification"
    Rails.logger.info "[CC_NOTIFICATION]    Action: #{@item[:type]}"
    Rails.logger.info "[CC_NOTIFICATION]    Ticket: ##{ticket.id} (#{ticket.title})"
    Rails.logger.info "[CC_NOTIFICATION]    CC: ##{cc_record.id}"
    
    result = NotificationFactory::Mailer.notification(
      template:    'ticket_cc_notification',
      user:        user,
      objects:     build_objects(user),
      message_id:  "<cc.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
      references:  ticket.get_references,
      main_object: ticket,
    )
    
    Rails.logger.info "[CC_NOTIFICATION] ✅ Email sent successfully to #{user.email}"
  rescue Channel::DeliveryError => e
    status_code = begin
      e.original_error.response.status.to_i
    rescue
      raise e
    end
    
    if SILENCABLE_SMTP_ERROR_CODES.any? { |elem| elem.include? status_code }
      Rails.logger.info "[CC_NOTIFICATION] ⚠️  Email delivery failed (silenced SMTP error)"
      Rails.logger.info "[CC_NOTIFICATION]    Status code: #{status_code}"
      return
    end
    
    Rails.logger.error "[CC_NOTIFICATION] ❌ Email delivery failed (critical error)"
    Rails.logger.error "[CC_NOTIFICATION]    Error: #{e.message}"
    raise e
  rescue StandardError => e
    Rails.logger.error "[CC_NOTIFICATION] ❌ Unexpected error sending email to #{user.email}"
    Rails.logger.error "[CC_NOTIFICATION]    Error class: #{e.class.name}"
    Rails.logger.error "[CC_NOTIFICATION]    Error message: #{e.message}"
    Rails.logger.error "[CC_NOTIFICATION]    Backtrace: #{e.backtrace.first(5).join("\n")}"
    raise e
  end
  
  def add_recipient_list_to_history(ticket, user, channels, type)
    return if channels.blank?
    
    identifier = user.email.presence || user.login
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
    if user.id == cc_record.user_id
      __('You are receiving this because you were CC\'d on this ticket.')
    else
      __('You are receiving this because you CC\'d someone on this ticket.')
    end
  end
  
  def build_objects(user)
    {
      ticket:          ticket,
      cc:              cc_record,
      cc_user:         cc_record.user,
      cc_user_name:    cc_record.user_name,
      created_by:      cc_record.created_by,
      created_by_name: cc_record.created_by_name,
      recipient:       user,
      current_user:    current_user,
      reason:          recipients_reason[user.id],
      url:             ticket_url
    }
  end
  
  def ticket_url
    "#{Setting.get('http_type')}://#{Setting.get('fqdn')}/#/ticket/zoom/#{ticket.id}"
  end
end

