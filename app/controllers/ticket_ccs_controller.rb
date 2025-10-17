# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketCcsController < ApplicationController
  before_action :authenticate_and_authorize!
  before_action :set_ticket, except: [:search_users]
  before_action :check_permissions, except: [:search_users]
  before_action :set_cc, only: %i[destroy]
  
  def index
    ccs = Service::Ticket::Cc::List
      .new(current_user: current_user)
      .execute(ticket: @ticket)
    
    render json: { ccs: ccs.map { |cc| serialize_cc(cc) } }
  end
  
  # Search for users that can be CC'd (agents and customers only)
  def search_users
    # Get Agent and Customer roles
    agent_role = Role.find_by(name: 'Agent')
    customer_role = Role.find_by(name: 'Customer')
    
    if agent_role.blank? && customer_role.blank?
      render json: { error: 'Agent or Customer roles not found' }, status: :unprocessable_entity
      return
    end
    
    role_ids = [agent_role&.id, customer_role&.id].compact
    
    # Search users with these roles
    search_result = User.search(
      query:            params[:query] || params[:term] || '',
      role_ids:         role_ids,
      limit:            params[:limit] || 50,
      current_user:     current_user,
      full:             true,
      with_total_count: false,
    )
    
    users = search_result.is_a?(Hash) ? (search_result[:objects] || []) : []
    
    # Filter out current user and inactive users
    users = users.select { |u| u.active && u.id != current_user.id }
    
    # Format for autocomplete
    result = users.map do |user|
      realname = user.fullname(recipient_line: true) || user.fullname || user.email || user.id.to_s
      value = user.email || realname
      
      {
        id: user.id,
        label: realname,
        value: realname,
        inactive: !user.active
      }
    end
    
    render json: result, status: :ok
  rescue StandardError => e
    Rails.logger.error "CC search_users error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: "Search failed: #{e.message}" }, status: :internal_server_error
  end
  
  def create
    cc = Service::Ticket::Cc::Create
      .new(current_user: current_user)
      .execute(
        ticket:  @ticket,
        user_id: cc_create_params[:user_id],
        message: cc_create_params[:message]
      )
    
    render json: { cc: serialize_cc(cc) }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: __('User not found') }, status: :not_found
  rescue Exceptions::UnprocessableEntity => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  def destroy
    cc_data = Service::Ticket::Cc::Destroy
      .new(current_user: current_user)
      .execute(cc: @cc)
    
    render json: { success: true, cc: serialize_cc(cc_data) }
  rescue Exceptions::Forbidden => e
    render json: { error: e.message }, status: :forbidden
  end
  
  private
  
  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
  end
  
  def set_cc
    @cc = @ticket.ccs.find(params[:id])
  end
  
  def check_permissions
    authorize!(@ticket, :show?)
  end
  
  def cc_create_params
    params.permit(:user_id, :message)
  end
  
  def serialize_cc(cc)
    user_id = extract_attribute(cc, :user_id)
    user_name = extract_attribute(cc, :user_name) || cc.try(:user)&.fullname || cc.try(:user)&.email
    
    {
      id:              stringify_id(extract_attribute(cc, :id)),
      ticket_id:       stringify_id(extract_attribute(cc, :ticket_id)),
      user_id:         stringify_id(user_id),
      user_name:       user_name,
      permissions:     Array(extract_attribute(cc, :permissions)),
      message:         extract_attribute(cc, :message),
      created_by_id:   stringify_id(extract_attribute(cc, :created_by_id)),
      created_by_name: cc.respond_to?(:created_by) ? cc.created_by&.fullname : cc[:created_by_name],
      created_at:      extract_attribute(cc, :created_at),
      updated_at:      extract_attribute(cc, :updated_at)
    }
  end
  
  def extract_attribute(source, key)
    if source.respond_to?(key)
      source.public_send(key)
    elsif source.respond_to?(:[])
      source[key]
    end
  end
  
  def stringify_id(value)
    value.present? ? value.to_s : nil
  end
end

