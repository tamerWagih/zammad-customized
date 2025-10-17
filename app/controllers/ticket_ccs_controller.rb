# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketCcsController < ApplicationController
  prepend_before_action :authentication_check, only: [:search_users]
  before_action :authenticate_and_authorize!, except: [:search_users]
  before_action :set_ticket, except: [:search_users]
  before_action :check_permissions, except: [:search_users]
  before_action :set_cc, only: %i[destroy]
  
  def search_users
    Rails.logger.info "[CC_SEARCH] ========== ENDPOINT CALLED =========="
    Rails.logger.info "[CC_SEARCH] Params: #{params.inspect}"
    
    begin
      Rails.logger.info "[CC_SEARCH] Current user: #{current_user&.id}"
    rescue => e
      Rails.logger.error "[CC_SEARCH] Error getting current_user: #{e.message}"
    end
    
    query = params[:query] || params[:term] || ''
    limit = (params[:limit] || 50).to_i
    
    Rails.logger.info "[CC_SEARCH] Query: '#{query}', Limit: #{limit}"
    
    # Get Agent and Customer roles - use exact name lookup
    agent_role_id = Role.where(name: 'Agent').pluck(:id).first
    customer_role_id = Role.where(name: 'Customer').pluck(:id).first
    
    Rails.logger.info "[CC_SEARCH] Agent role ID: #{agent_role_id}, Customer role ID: #{customer_role_id}"
    
    if agent_role_id.nil? && customer_role_id.nil?
      Rails.logger.warn "[CC_SEARCH] ⚠️  No Agent or Customer roles found!"
      return render json: { record_ids: [], assets: {} }
    end
    
    role_ids = [agent_role_id, customer_role_id].compact
    Rails.logger.info "[CC_SEARCH] Role IDs to search: #{role_ids.inspect}"
    
    # Get user IDs with these roles using a subquery to avoid JOIN issues
    user_ids_with_roles = RolesUser.where(role_id: role_ids).pluck(:user_id).uniq
    
    Rails.logger.info "[CC_SEARCH] Found #{user_ids_with_roles.count} users with Agent/Customer roles"
    
    # Get users by IDs
    users = User.where(id: user_ids_with_roles)
                .where(active: true)
                .where.not(email: [nil, ''])
                .where.not(id: current_user&.id)  # Exclude current user
    
    Rails.logger.info "[CC_SEARCH] Active users with email (excluding current): #{users.count}"
    
    # Filter by query if provided
    if query.present?
      search_term = "%#{User.sanitize_sql_like(query.downcase)}%"
      users = users.where(
        'LOWER(firstname) LIKE ? OR LOWER(lastname) LIKE ? OR LOWER(email) LIKE ? OR LOWER(login) LIKE ?',
        search_term, search_term, search_term, search_term
      )
      Rails.logger.info "[CC_SEARCH] After query filter: #{users.count} users"
    end
    
    # Order and limit results
    users = users.order(Arel.sql('LOWER(firstname), LOWER(lastname), LOWER(email)'))
                 .limit(limit)
    
    Rails.logger.info "[CC_SEARCH] After order/limit: #{users.count}"
    
    # Build assets hash
    assets = {}
    record_ids = []
    
    users.each do |user|
      record_ids << user.id
      assets = user.assets(assets)
    end
    
    Rails.logger.info "[CC_SEARCH] ✅ SUCCESS - Returning #{record_ids.count} users"
    
    # Return in format expected by user_autocompletion (same as /users/search)
    render json: {
      record_ids: record_ids,
      assets: assets
    }
  rescue => e
    Rails.logger.error "[CC_SEARCH] ❌ EXCEPTION CAUGHT: #{e.class.name}"
    Rails.logger.error "[CC_SEARCH] Message: #{e.message}"
    Rails.logger.error "[CC_SEARCH] Backtrace:"
    e.backtrace.first(15).each { |line| Rails.logger.error "[CC_SEARCH]   #{line}" }
    render json: { error: 'Search failed', record_ids: [], assets: {} }, status: :internal_server_error
  end
  
  def index
    ccs = Service::Ticket::Cc::List
      .new(current_user: current_user)
      .execute(ticket: @ticket)
    
    render json: { ccs: ccs.map { |cc| serialize_cc(cc) } }
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

