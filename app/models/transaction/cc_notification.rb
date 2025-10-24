# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Transaction::CcNotification
  include ChecksHumanChanges

  SILENCABLE_SMTP_ERROR_CODES = [400..499, 520..529, 550..559].freeze

  attr_accessor :recipients_and_channels, :recipients_reason

  def initialize(item, params = {})
    @item                    = item
    @params                  = params
    @recipients_and_channels = []
    @recipients_reason       = {}
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
    Rails.logger.info "[CC_NOTIFICATION] ===== PERFORM CALLED ====="
    Rails.logger.info "[CC_NOTIFICATION] Item: #{@item.inspect}"
    
    # Only process Ticket::Cc objects
    if @item[:object] != 'Ticket::Cc'
      Rails.logger.info "[CC_NOTIFICATION] Skipping - not Ticket::Cc object"
      return
    end
    
    if Setting.get('import_mode')
      Rails.logger.info "[CC_NOTIFICATION] Skipping - import mode"
      return
    end
    
    if cc_record.blank? || ticket.blank?
      Rails.logger.warn "[CC_NOTIFICATION] Skipping - missing cc_record or ticket"
      return
    end
    
    if @params[:disable_notification]
      Rails.logger.info "[CC_NOTIFICATION] Skipping - notifications disabled"
      return
    end
    
    if @params[:send_notification] == false
      Rails.logger.info "[CC_NOTIFICATION] Skipping - send_notification false"
      return
    end

    Rails.logger.info "[CC_NOTIFICATION] Processing CC notification for ticket #{ticket.id}"
    prepare_recipients_and_reasons
    
    Rails.logger.info "[CC_NOTIFICATION] Found #{recipients_and_channels.length} recipients"

    # Send notifications
    recipients_and_channels.each do |recipient_settings|
      send_to_single_recipient(recipient_settings)
    end
    
    Rails.logger.info "[CC_NOTIFICATION] ===== PERFORM COMPLETE ====="
    true
  end

  def prepare_recipients_and_reasons
    possible_recipients = get_recipients
    recipients_reason_by_notifications_settings(possible_recipients)
  end

  def get_recipients
    recipients = []

    # Only send to the CC'd user (not the creator)
    # The creator doesn't need a confirmation email every time they CC someone
    if cc_record.user_id.present?
      cc_user = ::User.find_by(id: cc_record.user_id)
      recipients << cc_user if cc_user
      Rails.logger.info "[CC_NOTIFICATION] Recipient: #{cc_user.login} (CC'd user)"
    end

    recipients.compact.uniq
  end

  def recipients_reason_by_notifications_settings(possible_recipients)
    already_checked_recipient_ids = {}
    possible_recipients.each do |user|
      # Use 'cc' as notification type
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

    return if !user.active?

    blocked_in_days = user.mail_delivery_failed_blocked_days
    return if blocked_in_days.positive?

    used_channels = []
    return add_recipient_list_to_history(ticket, user, used_channels, @item[:type]) if !channels['email']
    return add_recipient_list_to_history(ticket, user, used_channels, @item[:type]) if user.email.blank?

    used_channels.push 'email'
    add_recipient_list_to_history(ticket, user, used_channels, @item[:type])

    template_objects = build_objects(user)

    NotificationFactory::Mailer.notification(
      template:    'ticket_cc_notification',
      user:        user,
      objects:     template_objects,
      message_id:  "<cc.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
      references:  ticket.get_references,
      main_object: ticket,
    )
  rescue => e
    Rails.logger.error "[CC_NOTIFICATION] Error sending email: #{e.message}"
    raise e
  end

  def add_recipient_list_to_history(ticket, user, channels, type)
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
    cc_obj = cc_record
    cc_user = ::User.find_by(id: cc_obj.user_id) if cc_obj.user_id
    creator = ::User.find_by(id: cc_obj.created_by_id) if cc_obj.created_by_id

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

