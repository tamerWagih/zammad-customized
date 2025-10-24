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
    # Only process Ticket::Cc objects
    return if @item[:object] != 'Ticket::Cc'
    return if Setting.get('import_mode')
    return if cc_record.blank? || ticket.blank?
    return if @params[:disable_notification]
    return if @params[:send_notification] == false

    prepare_recipients_and_reasons

    # Send notifications
    recipients_and_channels.each do |recipient_settings|
      send_to_single_recipient(recipient_settings)
    end
    
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
    end

    recipients.compact.uniq
  end

  def recipients_reason_by_notifications_settings(possible_recipients)
    already_checked_recipient_ids = {}
    possible_recipients.each do |user|
      # IMPORTANT: CC notifications should ALWAYS be sent regardless of user notification preferences
      # Being CC'd is an explicit action by another user, so notifications are expected
      # Override user preferences and always send email
      
      next if already_checked_recipient_ids[user.id]
      next if user.email.blank?
      next if !user.active?

      already_checked_recipient_ids[user.id] = true
      
      # Force email channel for CC notifications
      result = {
        user: user,
        channels: {
          'email' => true,
          'online' => true  # Also send online notification
        }
      }
      
      @recipients_and_channels.push result
      @recipients_reason[user.id] ||= get_reason_for_user(user)
    end
  end

  def send_to_single_recipient(recipient_settings)
    user     = recipient_settings[:user]
    channels = recipient_settings[:channels]

    return if !user.active?

    blocked_in_days = user.mail_delivery_failed_blocked_days
    return if blocked_in_days.positive?

    used_channels = []
    
    # Send online notification if requested
    if channels['online']
      send_online_notification(user)
      used_channels.push 'online'
    end
    
    # Send email notification if requested
    if channels['email'] && user.email.present?
      template_objects = build_objects(user)

      NotificationFactory::Mailer.notification(
        template:    'ticket_cc_notification',
        user:        user,
        objects:     template_objects,
        message_id:  "<cc.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
        references:  ticket.get_references,
        main_object: ticket,
      )
      used_channels.push 'email'
    end
    
    add_recipient_list_to_history(ticket, user, used_channels, @item[:type])
  rescue => e
    raise e
  end

  def send_online_notification(user)
    # Send online notification via WebSocket
    # This creates a notification that appears in the user's notification panel
    # CRITICAL: Use correct type format to match activityMessage() in ticket.coffee
    notification_type = case @item[:type]
    when 'create'
      'Ticket/Cc created'
    when 'update'
      'Ticket/Cc updated'
    when 'delete'
      'Ticket/Cc deleted'
    else
      'Ticket/Cc created'  # Default
    end
    
    OnlineNotification.add(
      type:          notification_type,
      object:        'Ticket',
      o_id:          ticket.id,
      seen:          false,
      user_id:       user.id,
      created_by_id: current_user.id,
    )
  rescue => e
    # Silently fail for online notifications
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

