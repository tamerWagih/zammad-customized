# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::CC < ApplicationModel
  include HasActivityStreamLog
  include HasSearchIndexBackend
  include HasTags
  include HasTransactionDispatcher
  include Ticket::CC::TriggersNotifications
  
  VALID_PERMISSIONS = %w[read comment full].freeze
  
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
  
  def full_access?
    Array(permissions).include?('full')
  end
  
  def read_access?
    Array(permissions).include?('read') || full_access?
  end
  
  def comment_access?
    Array(permissions).include?('comment') || full_access?
  end
  
  def user_name
    user&.fullname || user&.email || 'Unknown User'
  end
  
  def created_by_name
    created_by&.fullname
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
      methods: %i[user_name created_by_name]
    }.merge(options))
  end
  
  private
  
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

