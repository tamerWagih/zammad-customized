class Service::Ticket::Share::EmailNotifier
  def initialize(current_user:)
    @current_user = current_user
  end

  def notify(share:, action:)
    return unless share.persisted?

    recipients_for(share).each do |recipient|
      begin
        send_notification(share, action, recipient)
      rescue => e
        Rails.logger.error "Failed to send share notification email to #{recipient.id}: #{e.message}"
      end
    end
  end

  private

  def recipients_for(share)
    # Only include agents and admins, not customers
    group_users = Array(User.group_access(share.group, 'read')).select(&:active?)
    agent_users = group_users.select { |user| user.permissions?('ticket.agent') }
    
    recipients = agent_users.dup
    recipients << share.shared_by if share.shared_by&.active? && share.shared_by.permissions?('ticket.agent')
    recipients << @current_user if @current_user&.active? && @current_user.permissions?('ticket.agent')
    recipients.uniq { |user| user.id }
  rescue => e
    Rails.logger.error "Failed to build share recipients: #{e.message}"
    # Fallback to just the shared_by user if they're an agent
    if share.shared_by&.active? && share.shared_by.permissions?('ticket.agent')
      [share.shared_by]
    else
      []
    end
  end

  def send_notification(share, action, recipient)
    NotificationFactory::Mailer.notification(
      template: 'ticket_share_notification',
      user:     recipient,
      objects:  build_objects(share, action, recipient)
    )
  end

  def build_objects(share, action, recipient)
    {
      ticket:    share.ticket,
      share:     share,
      actor:     @current_user,
      recipient: recipient,
      action:    action.to_s,
      url:       ticket_url(share.ticket)
    }
  end

  def ticket_url(ticket)
    "#{Setting.get('http_type')}://#{Setting.get('fqdn')}/#/ticket/zoom/#{ticket.id}"
  end
end
