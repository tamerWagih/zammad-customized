class Ticket::Approval < ApplicationRecord
  self.table_name = 'ticket_approvals'

  belongs_to :ticket, class_name: 'Ticket'
  belongs_to :approver, class_name: 'User'

  validates :ticket_id, presence: true
  validates :approver_id, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  def pending?
    status == 'pending'
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end
end
