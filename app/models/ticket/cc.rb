# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Cc < ApplicationModel
  # CRITICAL: These includes handle everything automatically!
  include HasActivityStreamLog          # Activity logging
  include HasSearchIndexBackend         # Elasticsearch
  include ChecksClientNotification      # WebSocket broadcasts (CRITICAL!)
  include HasTags                       # Tag support
  include HasTransactionDispatcher      # Transaction events (CRITICAL!)
  include Ticket::Cc::TriggersSubscriptions  # Custom WebSocket events
  include ApplicationModel::HasRequestCache  # Clear Auth::RequestCache on commit (performance)

  PERMISSIONS = %w[read comment full].freeze

  belongs_to :ticket, touch: true
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

    # Allow users who have Agent OR Customer ROLE (not permission)
    # IMPORTANT: Use role_ids, NOT permissions?() - Admins have all permissions!
    # Users can have multiple roles - if ANY role is Agent or Customer, allow them
    agent_role = Role.find_by(name: 'Agent')
    customer_role = Role.find_by(name: 'Customer')
    
    return if user.role_ids.include?(agent_role&.id) || user.role_ids.include?(customer_role&.id)

    errors.add(:user_id, 'must have Agent or Customer role')
  end

  def set_default_permissions
    # CRITICAL: Check if permissions are already explicitly set
    # Don't override if array has content
    if permissions.is_a?(Array) && permissions.length > 0
      return
    end

    # Set permissions based on user ROLE AND group membership:
    # - Agents IN the ticket's group: full access (can read, comment, edit)
    # - Agents NOT in the ticket's group: read + comment only (can view and respond)
    # - Customers: read + comment (can view and respond)
    
    return unless user
    return unless ticket
    
    agent_role = Role.find_by(name: 'Agent')
    customer_role = Role.find_by(name: 'Customer')
    
    if user.role_ids.include?(agent_role&.id)
      # Check if agent has access to the ticket's group
      if user.group_access?(ticket.group_id, 'full')
        # Agent with full group access gets full ticket access
        self.permissions = ['full']
      else
        # Agent WITHOUT full group access only gets read + comment
        # This is for agents CC'd from other departments
        self.permissions = ['read', 'comment']
      end
    elsif user.role_ids.include?(customer_role&.id)
      # Users with Customer role get read and comment access
      self.permissions = ['read', 'comment']
    else
      # Fallback: read + comment (shouldn't happen due to validation)
      self.permissions = ['read', 'comment']
    end
  end

  def search_index_attribute_lookup(record)
    attributes = super(record)
    attributes.merge(
      user:        user_name,
      permissions: Array(permissions).join(', '),
    )
  end

  def activity_message
    "User #{user_name} was CC'd on this ticket"
  end
end

