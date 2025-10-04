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
    group_members = Array(User.group_access(share.group, 'read')).select(&:active?)
    group_members << share.shared_by if share.shared_by&.active?
    group_members << @current_user if @current_user&.active?
    group_members.uniq { |user| user.id }
  rescue => e
    Rails.logger.error "Failed to build share recipients: #{e.message}"
    share.shared_by ? [share.shared_by] : []
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
