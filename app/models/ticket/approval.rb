# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Approval < ApplicationModel
  include HasActivityStreamLog
  include HasSearchIndexBackend
  include ChecksClientNotification
  include HasTags
  include HasTransactionDispatcher
  include Ticket::Approval::TriggersNotifications
  include ApplicationModel::HasRequestCache  # Clear Auth::RequestCache on commit (performance)

  PRIORITIES = %w[low normal high urgent].freeze
  STATUSES   = %w[pending approved rejected].freeze

  belongs_to :ticket  # Note: TriggersSubscriptions handles WebSocket updates, touch: true removed for performance
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

  # Public methods for approve/reject actions
  def approve!
    # Use update! instead of update_columns to trigger callbacks and HasTransactionDispatcher
    # This ensures only ONE transaction event is created, not two
    update!(status: 'approved')
  end

  def reject!
    # Use update! instead of update_columns to trigger callbacks and HasTransactionDispatcher
    # This ensures only ONE transaction event is created, not two
    update!(status: 'rejected')
  end

  # Status check methods
  def pending?
    status == 'pending'
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end

  # Name accessor methods
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
    attributes = super(record)
    attributes.merge(
      approver:  approver&.fullname,
      requester: requester&.fullname,
    )
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
