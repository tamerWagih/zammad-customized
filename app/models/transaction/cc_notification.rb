# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Transaction::CcNotification < Transaction::Notification

  def get_recipients
    recipients = []
    
    # CC user gets notification
    cc_user = cc_record.user
    if cc_user&.active?
      recipients << cc_user
    end
    
    # Creator gets notification (optional)
    creator = cc_record.created_by
    if creator&.active? && creator.id != cc_user.id
      recipients << creator
    end
    
    recipients.compact.uniq
  end

  def send_to_single_recipient(recipient_settings)
    return if !recipient_settings[:email]

    # Get ticket and CC record
    ticket = cc_record.ticket
    return if !ticket

    # Send email notification
    NotificationFactory::Mailer.notification(
      template: 'ticket_cc_notification',
      user: recipient_settings[:user],
      objects: {
        ticket: ticket,
        cc: cc_record,
        recipient: recipient_settings[:user]
      },
      preferences: {
        online: recipient_settings[:online],
        email: recipient_settings[:email]
      }
    )
  end

  private

  def cc_record
    @cc_record ||= Ticket::Cc.find(transaction_options['cc_id'])
  end
end
