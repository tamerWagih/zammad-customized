# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Approval < ApplicationModel
  include HasActivityStreamLog
  include HasSearchIndexBackend
  # NOTE: ChecksClientNotification removed - parent Ticket model handles WebSocket via TriggersSubscriptions
  include HasTags
  include HasTransactionDispatcher
  include Ticket::Approval::TriggersNotifications

  PRIORITIES = %w[low normal high urgent].freeze
  STATUSES   = %w[pending approved rejected].freeze

  belongs_to :ticket, touch: true  # Touch parent ticket to trigger its TriggersSubscriptions
  belongs_to :approver, class_name: 'User'
  belongs_to :requester, class_name: 'User'
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :ticket_id, presence: true
  validates :approver_id, presence: true
  validates :approver_id, uniqueness: { scope: :ticket_id, conditions: -> { where(status: 'pending') } }, if: :pending_status?
  validates :priority, inclusion: { in: PRIORITIES }

  scope :pending,  -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  def approve!
    update!(status: 'approved')
    
    # Trigger specific 'approve' action type for notifications
    EventBuffer.add('transaction', {
      object:     'Ticket::Approval',
      type:       'approve',
      object_id:  id,
      data:       {
        ticket_id: ticket_id,
        approver_id: approver_id,
        requester_id: requester_id,
        status: 'approved',
        message: message,
        priority: priority
      },
      user_id:    UserInfo.current_user_id,
      created_at: Time.zone.now,
    })
    
    Rails.logger.info "[APPROVAL_NOTIFICATION] ✅ APPROVE event added to EventBuffer for approval ##{id}"
  end

  def reject!
    update!(status: 'rejected')
    
    # Trigger specific 'reject' action type for notifications
    EventBuffer.add('transaction', {
      object:     'Ticket::Approval',
      type:       'reject',
      object_id:  id,
      data:       {
        ticket_id: ticket_id,
        approver_id: approver_id,
        requester_id: requester_id,
        status: 'rejected',
        message: message,
        priority: priority
      },
      user_id:    UserInfo.current_user_id,
      created_at: Time.zone.now,
    })
    
    Rails.logger.info "[APPROVAL_NOTIFICATION] ✅ REJECT event added to EventBuffer for approval ##{id}"
  end

  def pending?
    status == 'pending'
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end

  def approver_name
    approver&.fullname
  end

  def requester_name
    requester&.fullname
  end

  def as_json(options = {})
    super({
      only: %i[
        id
        ticket_id
        approver_id
        requester_id
        status
        message
        priority
        created_at
        updated_at
      ],
      methods: %i[approver_name requester_name]
    }.merge(options))
  end

  private

  def pending_status?
    status.blank? || status == 'pending'
  end

  def search_index_attribute_lookup(record)
    {
      ticket_id: record.ticket_id,
      approver:  record.approver&.fullname,
      requester: record.requester&.fullname,
      status:    record.status,
      message:   record.message,
    }
  end

  def activity_message
    case status
    when 'pending'
      "Approval request sent to #{approver_name}"
    when 'approved'
      "Approval request approved by #{approver_name}"
    when 'rejected'
      "Approval request rejected by #{approver_name}"
    else
      "Approval request status changed to #{status}"
    end
  end

end
