# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Share < ApplicationModel
  include HasActivityStreamLog
  include HasSearchIndexBackend
  include ChecksClientNotification
  include HasTags
  include Ticket::Share::TriggersSubscriptions

  VALID_PERMISSIONS = %w[read comment edit].freeze

  belongs_to :ticket
  belongs_to :shared_with, class_name: 'User'
  belongs_to :shared_by, class_name: 'User'

  validates :ticket_id, presence: true
  validates :shared_with_id, presence: true
  validates :shared_with_id, uniqueness: { scope: :ticket_id, conditions: -> { where(status: 'active') } }, if: :active_status?
  validates :permissions, presence: true
  validate :valid_permissions

  scope :with_permission, ->(permission) { where("permissions ? '#{permission}'") }
  scope :readable, -> { with_permission('read') }
  scope :editable, -> { with_permission('edit') }
  scope :active_current, -> { where(status: 'active').where('expires_at IS NULL OR expires_at > ?', Time.current) }

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

  def shared_with_name
    shared_with&.fullname
  end

  def shared_by_name
    shared_by&.fullname
  end

  def as_json(options = {})
    super({
      only: %i[
        id
        ticket_id
        shared_with_id
        shared_by_id
        permissions
        message
        status
        created_at
        updated_at
        expires_at
      ],
      methods: %i[shared_with_name shared_by_name]
    }.merge(options))
  end

  private

  def active_status?
    status.blank? || status == 'active'
  end

  def valid_permissions
    invalid_perms = Array(permissions) - VALID_PERMISSIONS

    if invalid_perms.any?
      errors.add(:permissions, "contains invalid permissions: #{invalid_perms.join(', ')}")
    end

    if Array(permissions).blank?
      errors.add(:permissions, 'must contain at least one permission')
    end
  end

  def search_index_attribute_lookup(record)
    {
      ticket_id: record.ticket_id,
      shared_with: record.shared_with&.fullname,
      shared_by:   record.shared_by&.fullname,
      permissions: Array(record.permissions).join(', '),
      message:     record.message,
    }
  end

  def activity_message
    case status
    when 'active'
      "Ticket shared with #{shared_with_name} (#{Array(permissions).join(', ')})"
    when 'revoked'
      "Share revoked for #{shared_with_name}"
    else
      "Share status changed to #{status}"
    end
  end
end
