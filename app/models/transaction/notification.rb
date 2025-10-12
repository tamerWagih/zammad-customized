# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Transaction::Notification
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
    object: 'Ticket',
    type: 'update',
    object_id: 123,
    interface_handle: 'application_server', # application_server|websocket|scheduler
    changes: {
      'attribute1' => [before, now],
      'attribute2' => [before, now],
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

  def ticket
    @ticket ||= Ticket.find_by(id: @item[:object_id])
  end

  def article_by_item
    return if !@item[:article_id]

    article = Ticket::Article.find(@item[:article_id])

    # ignore notifications
    sender = Ticket::Article::Sender.lookup(id: article.sender_id)
    if sender&.name == 'System'
      return if @item[:changes].blank? && article.preferences[:notification] != true

      if article.preferences[:notification] != true
        article = nil
      end
    end

    article
  end

  def article
    @article ||= article_by_item
  end

  def current_user
    @current_user ||= User.lookup(id: @item[:user_id]) || User.lookup(id: 1)
  end

  def perform
    Rails.logger.info "[NOTIFICATION] 🔔 Transaction::Notification.perform called"
    Rails.logger.info "[NOTIFICATION] 📋 Item: #{@item[:object]} ##{@item[:object_id]} (#{@item[:type]})"
    
    # return if we run import mode
    if Setting.get('import_mode')
      Rails.logger.info "[NOTIFICATION] ⏭️  Skipping: import_mode enabled"
      return
    end
    
    if %w[Ticket Ticket::Article].exclude?(@item[:object])
      Rails.logger.info "[NOTIFICATION] ⏭️  Skipping: object type #{@item[:object]} not Ticket or Ticket::Article"
      return
    end
    
    if @params[:disable_notification]
      Rails.logger.info "[NOTIFICATION] ⏭️  Skipping: notifications disabled via params"
      return
    end
    
    if !ticket
      Rails.logger.info "[NOTIFICATION] ⏭️  Skipping: ticket not found"
      return
    end

    Rails.logger.info "[NOTIFICATION] ✅ Processing ticket ##{ticket.id} (#{ticket.title})"
    prepare_recipients_and_reasons
    Rails.logger.info "[NOTIFICATION] 📬 Found #{recipients_and_channels.count} recipients"

    # send notifications
    recipients_and_channels.each do |recipient_settings|
      send_to_single_recipient(recipient_settings)
    end
    
    Rails.logger.info "[NOTIFICATION] ✅ Notification processing completed"
  end

  def prepare_recipients_and_reasons

    # loop through all group users
    possible_recipients = possible_recipients_of_group(ticket.group_id)

    # loop through all mention users
    mention_users = Mention.where(mentionable_type: @item[:object], mentionable_id: @item[:object_id]).map(&:user)
    if mention_users.present?

      # only notify if read permission on group are given
      mention_users.each do |mention_user|
        next if !mention_user.group_access?(ticket.group_id, 'read')

        possible_recipients.push mention_user
        @recipients_reason[mention_user.id] = __('You are receiving this because you were mentioned in this ticket.')
      end
    end

    # apply owner
    if ticket.owner_id != 1
      possible_recipients.push ticket.owner
      @recipients_reason[ticket.owner_id] = __('You are receiving this because you are the owner of this ticket.')
    end

    # apply out of office agents
    possible_recipients_additions = Set.new
    possible_recipients.each do |user|
      ooo_replacements(
        user:         user,
        replacements: possible_recipients_additions,
        reasons:      recipients_reason,
        ticket:       ticket,
      )
    end

    if possible_recipients_additions.present?
      # join unique entries
      possible_recipients |= possible_recipients_additions.to_a
    end

    recipients_reason_by_notifications_settings(possible_recipients)
  end

  def recipients_reason_by_notifications_settings(possible_recipients)
    already_checked_recipient_ids = {}
    possible_recipients.each do |user|
      result = NotificationFactory::Mailer.notification_settings(user, ticket, @item[:type])
      next if !result
      next if already_checked_recipient_ids[user.id]

      already_checked_recipient_ids[user.id] = true
      @recipients_and_channels.push result
      next if recipients_reason[user.id]

      @recipients_reason[user.id] = __('You are receiving this because you are a member of the group of this ticket.')
    end
  end

  def recipient_myself?(user)
    return false if @params[:interface_handle] != 'application_server'
    return true if article&.updated_by_id == user.id
    return true if !article && @item[:user_id] == user.id

    false
  end

  def send_to_single_recipient(recipient_settings)
    user     = recipient_settings[:user]
    channels = recipient_settings[:channels]

    # ignore user who changed it by him self via web
    return if recipient_myself?(user)

    # ignore inactive users
    return if !user.active?

    blocked_in_days = user.mail_delivery_failed_blocked_days
    if blocked_in_days.positive?
      Rails.logger.info "Send no system notifications to #{user.email} because email is marked as mail_delivery_failed for #{blocked_in_days} day(s)"
      return
    end

    # ignore if no changes has been done
    changes = human_changes(@item[:changes], ticket, user)
    return if @item[:type] == 'update' && !article && changes.blank?

    # check if today already notified
    if %w[reminder_reached escalation escalation_warning].include?(@item[:type])
      identifier = user.email
      if !identifier || identifier == ''
        identifier = user.login
      end

      already_notified_cutoff = Time.use_zone(Setting.get('timezone_default')) { Time.current.beginning_of_day }

      already_notified = History.where(
        history_type_id:   History.type_lookup('notification').id,
        history_object_id: History.object_lookup('Ticket').id,
        o_id:              ticket.id
      ).where('created_at > ?', already_notified_cutoff).exists?(['value_to LIKE ?', "%#{SqlHelper.quote_like(identifier)}(#{SqlHelper.quote_like(@item[:type])}:%"])

      return if already_notified
    end

    # create online notification
    used_channels = []
    if channels['online']
      used_channels.push 'online'

      created_by_id = @item[:user_id] || 1

      # delete old notifications
      if @item[:type] == 'reminder_reached'
        seen = false
        created_by_id = 1
        OnlineNotification.remove_by_type('Ticket', ticket.id, @item[:type], user)

      elsif %w[escalation escalation_warning].include?(@item[:type])
        seen = false
        created_by_id = 1
        OnlineNotification.remove_by_type('Ticket', ticket.id, 'escalation', user)
        OnlineNotification.remove_by_type('Ticket', ticket.id, 'escalation_warning', user)

      # on updates without state changes create unseen messages
      elsif @item[:type] != 'create' && (@item[:changes].blank? || @item[:changes]['state_id'].blank?)
        seen = false
      else
        seen = OnlineNotification.seen_state?(ticket, user.id)
      end

      OnlineNotification.add(
        type:          @item[:type],
        object:        @item[:object],
        o_id:          @item[:object].eql?('Ticket') ? ticket.id : article.id,
        seen:          seen,
        created_by_id: created_by_id,
        user_id:       user.id,
      )
      Rails.logger.debug { "sent ticket online notification to agent (#{@item[:type]}/#{ticket.id}/#{user.email})" }
    end

    # ignore email channel notification and empty emails
    if !channels['email'] || user.email.blank?
      Rails.logger.info "[NOTIFICATION] ⏭️  Skipping email for #{user.email || user.login}: email channel disabled or no email address"
      add_recipient_list_to_history(ticket, user, used_channels, @item[:type])
      return
    end

    used_channels.push 'email'
    add_recipient_list_to_history(ticket, user, used_channels, @item[:type])

    # get user based notification template
    # if create, send create message / block update messages
    template = case @item[:type]
               when 'create'
                 'ticket_create'
               when 'update'
                 'ticket_update'
               when 'reminder_reached'
                 'ticket_reminder_reached'
               when 'escalation'
                 'ticket_escalation'
               when 'escalation_warning'
                 'ticket_escalation_warning'
               when 'update.merged_into'
                 'ticket_update_merged_into'
               when 'update.received_merge'
                 'ticket_update_received_merge'
               when 'update.reaction'
                 'ticket_article_update_reaction'
               else
                 raise "unknown type for notification #{@item[:type]}"
               end

    Rails.logger.info "[NOTIFICATION] 📧 Sending email notification to #{user.email}"
    Rails.logger.info "[NOTIFICATION]    Template: #{template}"
    Rails.logger.info "[NOTIFICATION]    Ticket: ##{ticket.id} (#{ticket.title})"
    Rails.logger.info "[NOTIFICATION]    Type: #{@item[:type]}"
    Rails.logger.info "[NOTIFICATION]    User: #{user.fullname} (#{user.email})"

    attachments = []
    if article
      attachments = article.attachments_inline
    end
    
    result = NotificationFactory::Mailer.notification(
      template:    template,
      user:        user,
      objects:     {
        ticket:       ticket,
        article:      article,
        recipient:    user,
        current_user: current_user,
        changes:      changes,
        reason:       recipients_reason[user.id],
      },
      message_id:  "<notification.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
      references:  ticket.get_references,
      main_object: ticket,
      attachments: attachments,
    )
    
    Rails.logger.info "[NOTIFICATION] ✅ Email sent successfully to #{user.email}"
    Rails.logger.info "[NOTIFICATION]    Subject: #{result[:subject] rescue 'N/A'}"
    Rails.logger.info "[NOTIFICATION]    From: #{Setting.get('notification_sender')}"
    Rails.logger.debug { "sent ticket email notification to agent (#{@item[:type]}/#{ticket.id}/#{user.email})" }
  rescue Channel::DeliveryError => e
    status_code = begin
      e.original_error.response.status.to_i
    rescue
      raise e
    end

    if SILENCABLE_SMTP_ERROR_CODES.any? { |elem| elem.include? status_code }
      Rails.logger.info "[NOTIFICATION] ⚠️  Email delivery failed (silenced error)"
      Rails.logger.info "[NOTIFICATION]    Status code: #{status_code}"
      Rails.logger.info "[NOTIFICATION]    Error: #{e.original_error}"
      Rails.logger.info do
        "could not send ticket email notification to agent (#{@item[:type]}/#{ticket.id}/#{user.email}) #{e.original_error}"
      end

      return
    end

    Rails.logger.error "[NOTIFICATION] ❌ Email delivery failed (critical error)"
    Rails.logger.error "[NOTIFICATION]    Status code: #{status_code}"
    Rails.logger.error "[NOTIFICATION]    Error: #{e.message}"
    raise e
  end

  def add_recipient_list_to_history(ticket, user, channels, type)
    return if channels.blank?

    identifier     = user.email.presence || user.login
    recipient_list = "#{identifier}(#{type}:#{channels.join(',')})"

    History.add(
      o_id:           ticket.id,
      history_type:   'notification',
      history_object: 'Ticket',
      value_to:       recipient_list,
      created_by_id:  @item[:user_id] || 1
    )
  end

  private

  def ooo_replacements(user:, replacements:, ticket:, reasons:)
    replacement = user.out_of_office_agent

    return if !replacement

    return if !TicketPolicy.new(replacement, ticket).agent_read_access?

    return if !replacements.add?(replacement)

    reasons[replacement.id] = __('You are receiving this because you are out-of-office replacement for a participant of this ticket.')
  end

  def possible_recipients_of_group(group_id)
    Rails.cache.fetch("User/notification/possible_recipients_of_group/#{group_id}/#{User.latest_change}", expires_in: 20.seconds) do
      User.group_access(group_id, 'full').sort_by(&:login)
    end
  end
end
