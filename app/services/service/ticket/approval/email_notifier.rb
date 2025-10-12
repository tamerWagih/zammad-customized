# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Approval::EmailNotifier
  def initialize(current_user:)
    @current_user = current_user
  end

  def notify(approval:, action:)
    return unless approval.persisted?

    # Send email to both parties with error handling
    begin
      send_to_approver(approval, action)
    rescue => e
      Rails.logger.error "Failed to send approval notification email to approver: #{e.message}"
    end

    begin
      send_to_requester(approval, action)
    rescue => e
      Rails.logger.error "Failed to send approval notification email to requester: #{e.message}"
    end
  end

  private

  def send_to_approver(approval, action)
    return if approval.approver_id == @current_user.id

    NotificationFactory::Mailer.notification(
      template: 'ticket_approval_notification',
      user:     approval.approver,
      objects:  build_objects(approval, action, approval.approver)
    )
  end

  def send_to_requester(approval, action)
    return if approval.requester_id == @current_user.id

    NotificationFactory::Mailer.notification(
      template: 'ticket_approval_notification',
      user:     approval.requester,
      objects:  build_objects(approval, action, approval.requester)
    )
  end

  def build_objects(approval, action, recipient)
    {
      ticket:    approval.ticket,
      approval:  approval,
      actor:     @current_user,
      recipient: recipient,
      action:    action.to_s,
      url:       ticket_url(approval.ticket)
    }
  end

  def ticket_url(ticket)
    "#{Setting.get('http_type')}://#{Setting.get('fqdn')}/#/ticket/zoom/#{ticket.id}"
  end
end
