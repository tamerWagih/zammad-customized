# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Share < ApplicationModel
  include HasActivityStreamLog
  include HasSearchIndexBackend
  include ChecksClientNotification
  include HasTags

  belongs_to :ticket
  belongs_to :shared_with, class_name: 'User'
  belongs_to :shared_by, class_name: 'User'

  validates :ticket_id, presence: true
  validates :shared_with_id, presence: true
  validates :shared_with_id, uniqueness: { scope: :ticket_id }
  validates :permissions, presence: true
  validate :valid_permissions

  scope :with_permission, ->(permission) { where("permissions ? '#{permission}'") }
  scope :readable, -> { with_permission('read') }
  scope :editable, -> { with_permission('edit') }

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

  def revoke!
    update!(status: 'revoked')
  end

  private

  def valid_permissions
    valid_perms = %w[read comment edit]
    invalid_perms = permissions - valid_perms
    
    if invalid_perms.any?
      errors.add(:permissions, "contains invalid permissions: #{invalid_perms.join(', ')}")
    end
    
    if permissions.empty?
      errors.add(:permissions, 'must contain at least one permission')
    end
  end

  def search_index_attribute_lookup(record)
    {
      ticket_id: record.ticket_id,
      shared_with: record.shared_with.fullname,
      permissions: record.permissions.join(', '),
      message: record.message,
    }
  end

  def as_json(options = {})
    super(only: %i[id message created_at expires_at status permissions], methods: %i[shared_with_name])
  end

  def shared_with_name
    shared_with&.fullname
  end

  def activity_message
    case status
    when 'active'
      "Ticket shared with #{shared_with&.fullname} (#{permissions.join(', ')})"
    when 'revoked'
      "Share revoked for #{shared_with&.fullname}"
    else
      "Share status changed to #{status}"
    end
  end
end