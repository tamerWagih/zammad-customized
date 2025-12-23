# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Share < ApplicationModel
  include HasActivityStreamLog
  include HasSearchIndexBackend
  include ChecksClientNotification
  include HasTags
  include HasTransactionDispatcher
  include Ticket::Share::TriggersNotifications
  include ApplicationModel::HasRequestCache  # Clear Auth::RequestCache on commit (performance)

  VALID_PERMISSIONS = %w[full comment].freeze

  before_validation :ensure_default_permission

  belongs_to :ticket  # Note: TriggersSubscriptions handles WebSocket updates, touch: true removed for performance
  belongs_to :group
  belongs_to :shared_by, class_name: 'User'
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  validates :ticket_id, presence: true
  validates :group_id, presence: true
  validates :group_id, uniqueness: { scope: :ticket_id, conditions: -> { where(status: 'active') } }, if: :active_status?
  validates :permissions, presence: true
  validate :valid_permissions

  scope :active_current, -> { where(status: 'active') }

  def full_access?
    Array(permissions).include?('full')
  end

  def comment_access?
    Array(permissions).include?('comment') || full_access?
  end

  def read_access?
    full_access? || comment_access?
  end

  def revoke!
    # Use update! instead of update_columns to trigger callbacks and HasTransactionDispatcher
    # This ensures only ONE transaction event is created, not two
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

  def ensure_default_permission
    # Default to comment permission for new shares
    self.permissions = ['comment'] if permissions.blank?
  end

  def search_index_attribute_lookup(record)
    attributes = super(record)
    attributes.merge(
      group:     group&.fullname || group&.name,
      shared_by: shared_by&.fullname,
      permissions: Array(permissions).join(', '),
    )
  end

  def activity_message
    permission_text = full_access? ? 'full access' : 'comment access'
    case status
    when 'active'
      "Ticket shared with group #{group_name} (#{permission_text})"
    when 'revoked'
      "Share revoked for group #{group_name}"
    else
      "Share status changed to #{status}"
    end
  end

end
