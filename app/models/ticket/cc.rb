# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Cc < ApplicationModel
  # CRITICAL: These includes handle everything automatically!
  include HasActivityStreamLog          # Activity logging
  include HasSearchIndexBackend         # Elasticsearch
  include ChecksClientNotification      # WebSocket broadcasts (CRITICAL!)
  include HasTags                       # Tag support
  include HasTransactionDispatcher      # Transaction events (CRITICAL!)
  include Ticket::Cc::TriggersSubscriptions  # Custom WebSocket events

  PERMISSIONS = %w[read comment full].freeze

  belongs_to :ticket, touch: true       # Touch parent = triggers parent subscriptions
  belongs_to :user
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  validates :ticket_id, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: :ticket_id }
  validates :permissions, presence: true
  validate :valid_permissions
  validate :user_is_agent_or_customer

  before_validation :set_default_permissions

  scope :active, -> { joins(:user).where(users: { active: true }) }

  def read_access?
    permissions.include?('read') || full_access?
  end

  def comment_access?
    permissions.include?('comment') || full_access?
  end

  def full_access?
    permissions.include?('full')
  end

  def user_name
    user&.fullname
  end

  def as_json(options = {})
    super({
      only: %i[
        id
        ticket_id
        user_id
        permissions
        message
        created_at
        updated_at
      ],
      methods: %i[user_name]
    }.merge(options))
  end

  private

  def valid_permissions
    return if permissions.blank?

    invalid_permissions = permissions - PERMISSIONS
    return unless invalid_permissions.any?

    errors.add(:permissions, "contains invalid permissions: #{invalid_permissions.join(', ')}")
  end

  def user_is_agent_or_customer
    return if user.blank?

    # Allow users who have Agent OR Customer permission (among their roles)
    # Users can have multiple roles - if ANY role is Agent or Customer, allow them
    return if user.permissions?('ticket.agent') || user.permissions?('ticket.customer')

    errors.add(:user_id, 'must have Agent or Customer role')
  end

  def set_default_permissions
    # CRITICAL: Check if permissions are already explicitly set
    # Don't override if array has content
    if permissions.is_a?(Array) && permissions.length > 0
      return
    end

    # Set permissions based on user role:
    # - Agents: full access (can read, comment, edit)
    # - Customers: read + comment (can view and respond)
    # Note: User may have multiple roles - we check for agent first (higher privilege)
    
    return unless user
    
    if user.permissions?('ticket.agent')
      # Agents get full ticket access
      self.permissions = ['full']
    elsif user.permissions?('ticket.customer')
      # Customers get read and comment access
      self.permissions = ['read', 'comment']
    else
      # Fallback: read + comment (shouldn't happen due to validation)
      self.permissions = ['read', 'comment']
    end
  end

  def search_index_attribute_lookup(record)
    {
      ticket_id:   record.ticket_id,
      user:        record.user_name,
      permissions: Array(record.permissions).join(', '),
      message:     record.message,
    }
  end

  def activity_message
    "User #{user_name} was CC'd on this ticket"
  end
end

