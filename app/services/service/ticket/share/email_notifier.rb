# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Share::EmailNotifier
  def initialize(current_user:)
    @current_user = current_user
  end

  def notify(share:, action:)
    return unless share.persisted?

    # Send email to both parties with error handling
    begin
      send_to_shared_user(share, action)
    rescue => e
      Rails.logger.error "Failed to send share notification email to shared user: #{e.message}"
    end

    begin
      send_to_sharer(share, action)
    rescue => e
      Rails.logger.error "Failed to send share notification email to sharer: #{e.message}"
    end
  end

  private

  def send_to_shared_user(share, action)
    return if share.shared_with_id == @current_user.id

    NotificationFactory::Mailer.notification(
      template: 'ticket_share_notification',
      user:     share.shared_with,
      objects:  build_objects(share, action, share.shared_with)
    )
  end

  def send_to_sharer(share, action)
    return if share.shared_by_id == @current_user.id

    NotificationFactory::Mailer.notification(
      template: 'ticket_share_notification',
      user:     share.shared_by,
      objects:  build_objects(share, action, share.shared_by)
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
