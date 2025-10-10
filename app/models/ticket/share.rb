# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Share < ApplicationModel
  include HasActivityStreamLog
  include HasSearchIndexBackend
  # NOTE: ChecksClientNotification removed - parent Ticket model handles WebSocket via TriggersSubscriptions
  include HasTags
  include HasTransactionDispatcher
  include Ticket::Share::TriggersNotifications

  VALID_PERMISSIONS = %w[full].freeze

  before_validation :ensure_full_permission

  belongs_to :ticket, touch: true  # Touch parent ticket to trigger its TriggersSubscriptions
  belongs_to :group
  belongs_to :shared_by, class_name: 'User'
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  validates :ticket_id, presence: true
  validates :group_id, presence: true
  validates :group_id, uniqueness: { scope: :ticket_id, conditions: -> { where(status: 'active') } }, if: :active_status?
  validates :permissions, presence: true
  validate :valid_permissions

  scope :active_current, -> { where(status: 'active').where('expires_at IS NULL OR expires_at > ?', Time.current) }

  def full_access?
    Array(permissions).include?('full')
  end

  def revoke!
    update!(status: 'revoked')
  end

  def group_name
    group&.fullname || group&.name || 'Unknown group'
  end

  def shared_by_name
    shared_by&.fullname
  end

  def as_json(options = {})
    super({
      only: %i[
        id
        ticket_id
        group_id
        shared_by_id
        permissions
        message
        status
        created_at
        updated_at
        expires_at
      ],
      methods: %i[group_name shared_by_name]
    }.merge(options))
  end

  private

  def active_status?
    status.blank? || status == 'active'
  end

  def valid_permissions
    perms = Array(permissions)
    invalid_perms = perms - VALID_PERMISSIONS

    if invalid_perms.any?
      errors.add(:permissions, "contains invalid permissions: #{invalid_perms.join(', ')}")
    end

    if perms.blank?
      errors.add(:permissions, 'must contain at least one permission')
    end
  end

  def ensure_full_permission
    self.permissions = ['full'] if permissions.blank?
  end

  def search_index_attribute_lookup(record)
    {
      ticket_id: record.ticket_id,
      group:     record.group&.fullname || record.group&.name,
      shared_by: record.shared_by&.fullname,
      permissions: Array(record.permissions).join(', '),
      message:     record.message,
    }
  end

  def activity_message
    case status
    when 'active'
      "Ticket shared with group #{group_name} (full access)"
    when 'revoked'
      "Share revoked for group #{group_name}"
    else
      "Share status changed to #{status}"
    end
  end

end
