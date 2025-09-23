# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Approval < ApplicationModel
  include HasActivityStreamLog
  include HasSearchIndexBackend
  include ChecksClientNotification
  include HasTags

  belongs_to :ticket
  belongs_to :approver, class_name: 'User'
  belongs_to :requester, class_name: 'User'

  validates :status, inclusion: { in: %w[pending approved rejected] }
  validates :ticket_id, presence: true
  validates :approver_id, presence: true
  validates :approver_id, uniqueness: { scope: :ticket_id }
  validates :priority, inclusion: { in: %w[low normal high urgent] }

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  def approve!
    update!(status: 'approved')
    ticket.update!(state: Ticket::State.find_by(name: 'open')) if ticket.state.name == 'pending approval'
  end

  def reject!
    update!(status: 'rejected')
    ticket.update!(state: Ticket::State.find_by(name: 'closed')) if ticket.state.name == 'pending approval'
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

  private

  def search_index_attribute_lookup(record)
    {
      ticket_id: record.ticket_id,
      approver: record.approver.fullname,
      status: record.status,
      message: record.message,
    }
  end

  def as_json(options = {})
    super(only: %i[id status message created_at priority], methods: %i[approver_name])
  end

  def approver_name
    approver&.fullname
  end
end