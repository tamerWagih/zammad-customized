# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::Cc < ApplicationModel
  include HasActivityStreamLog
  include HasSearchIndexBackend
  include HasTags
  include HasTransactionDispatcher
  include Ticket::Cc::TriggersNotifications
  include Ticket::Cc::TriggersSubscriptions

  PERMISSIONS = %w[read comment full].freeze

  belongs_to :ticket, touch: true  # Touch parent ticket to trigger its TriggersSubscriptions
  belongs_to :user
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  validates :ticket_id, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: :ticket_id }
  validates :permissions, presence: true
  validate :valid_permissions
  validate :user_is_agent_or_customer

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
    if invalid_permissions.any?
      errors.add(:permissions, "contains invalid permissions: #{invalid_permissions.join(', ')}")
    end
  end

  def user_is_agent_or_customer
    return if user.blank?

    unless user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
      errors.add(:user_id, 'must be an agent or customer')
    end
  end

  def set_default_permissions
    return if permissions.present?

    # Agents get full access, customers get read + comment
    if user&.permissions?('ticket.agent')
      self.permissions = ['full']
    else
      self.permissions = ['read', 'comment']
    end
  end

  def search_index_attribute_lookup(record)
    {
      ticket_id: record.ticket_id,
      user: record.user_name,
      permissions: Array(record.permissions).join(', '),
      message: record.message,
    }
  end

  def activity_message
    "User #{user_name} was CC'd on this ticket"
  end
end
