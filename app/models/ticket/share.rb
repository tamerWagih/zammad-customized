class Ticket::Share < ApplicationRecord
  self.table_name = 'ticket_shares'

  belongs_to :ticket, class_name: 'Ticket'
  belongs_to :shared_with, class_name: 'User'

  validates :ticket_id, presence: true
  validates :shared_with_id, presence: true
  validates :permissions, presence: true
  validate :valid_permissions

  scope :with_permission, ->(permission) { where("permissions @> ?", [permission].to_json) }

  def has_permission?(permission)
    permissions.include?(permission)
  end

  def can_read?
    has_permission?('read')
  end

  def can_comment?
    has_permission?('comment')
  end

  def can_edit?
    has_permission?('edit')
  end

  private

  def valid_permissions
    valid_perms = %w[read comment edit]
    invalid_perms = permissions - valid_perms
    
    if invalid_perms.any?
      errors.add(:permissions, "contains invalid permissions: #{invalid_perms.join(', ')}")
    end
  end
end
