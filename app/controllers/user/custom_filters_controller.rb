# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class User::CustomFiltersController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # GET /api/v1/user_custom_filters
  def index
    custom_filters = current_user.preferences[:custom_filters] || []
    
    render json: {
      custom_filters: custom_filters,
      overviews: Ticket::Overviews.all(current_user: current_user, ignore_user_conditions: false)
    }
  end

  # GET /api/v1/user_custom_filters/:id
  def show
    custom_filters = current_user.preferences[:custom_filters] || []
    filter = custom_filters.find { |f| f['id'] == params[:id] }
    
    if filter
      render json: filter
    else
      render json: { error: 'Filter not found' }, status: :not_found
    end
  end

  # POST /api/v1/user_custom_filters
  def create
    filter_params = params.permit(:name, :prio, :active, :group_by, condition: {}, order: {}, view: {})
    
    # Handle nested parameters properly
    if params[:condition].present?
      filter_params[:condition] = params[:condition].to_unsafe_h
    end
    
    if params[:order].present?
      filter_params[:order] = params[:order].to_unsafe_h
    end
    
    if params[:view].present?
      filter_params[:view] = params[:view].to_unsafe_h
    end
    
    # Handle group_by as string
    if params[:group_by].present?
      filter_params[:group_by] = params[:group_by].to_s
    end
    
    # Initialize custom_filters if not exists
    current_user.preferences[:custom_filters] ||= []
    
    # Generate unique ID for the filter
    filter_id = SecureRandom.uuid
    
    # Build the filter object
    new_filter = {
      'id' => filter_id,
      'name' => filter_params[:name],
      'link' => generate_link(filter_params[:name], filter_id),
      'condition' => filter_params[:condition] || {},
      'order' => filter_params[:order] || { 'by' => 'created_at', 'direction' => 'DESC' },
      'view' => filter_params[:view] || { 's' => ['number', 'title', 'customer', 'state', 'created_at'] },
      'group_by' => filter_params[:group_by] || '',
      'prio' => filter_params[:prio] || (current_user.preferences[:custom_filters].length + 1000),
      'active' => filter_params[:active].nil? ? true : filter_params[:active],
      'is_custom' => true,
      'user_id' => current_user.id,
      'created_at' => Time.zone.now.iso8601,
      'updated_at' => Time.zone.now.iso8601
    }
    
    current_user.preferences[:custom_filters] << new_filter
    
    if current_user.save
      render json: new_filter, status: :created
    else
      Rails.logger.error "Failed to save custom filter: #{current_user.errors.full_messages}"
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error creating custom filter: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  # PUT /api/v1/user_custom_filters/:id
  def update
    filter_params = params.permit(:name, :prio, :active, :group_by, condition: {}, order: {}, view: {})
    
    custom_filters = current_user.preferences[:custom_filters] || []
    filter_index = custom_filters.find_index { |f| f['id'] == params[:id] }
    
    if filter_index.nil?
      render json: { error: 'Filter not found' }, status: :not_found
      return
    end
    
    filter = custom_filters[filter_index]
    
    # Update filter attributes
    filter['name'] = filter_params[:name] if filter_params[:name].present?
    filter['condition'] = filter_params[:condition] if filter_params[:condition].present?
    filter['order'] = filter_params[:order] if filter_params[:order].present?
    filter['view'] = filter_params[:view] if filter_params[:view].present?
    filter['group_by'] = filter_params[:group_by] if filter_params.key?(:group_by)
    filter['prio'] = filter_params[:prio] if filter_params[:prio].present?
    filter['active'] = filter_params[:active] unless filter_params[:active].nil?
    filter['updated_at'] = Time.zone.now.iso8601
    
    # Update link if name changed
    if filter_params[:name].present?
      filter['link'] = generate_link(filter_params[:name], filter['id'])
    end
    
    current_user.preferences[:custom_filters][filter_index] = filter
    
    if current_user.save
      render json: filter
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/user_custom_filters/:id
  def destroy
    custom_filters = current_user.preferences[:custom_filters] || []
    filter_index = custom_filters.find_index { |f| f['id'] == params[:id] }
    
    if filter_index.nil?
      render json: { error: 'Filter not found' }, status: :not_found
      return
    end
    
    current_user.preferences[:custom_filters].delete_at(filter_index)
    
    if current_user.save
      render json: { success: true }
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/user_custom_filters_prio
  def prio
    prios = params[:prios] # Array of [id, prio] pairs
    
    custom_filters = current_user.preferences[:custom_filters] || []
    
    prios.each do |id, prio_value|
      filter = custom_filters.find { |f| f['id'] == id }
      filter['prio'] = prio_value if filter
    end
    
    current_user.preferences[:custom_filters] = custom_filters.sort_by { |f| f['prio'] }
    
    if current_user.save
      render json: { success: true }
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def generate_link(name, id)
    base_link = name.to_s.downcase.parameterize(separator: '_')
    base_link = 'custom_filter' if base_link.blank?
    "#{base_link}_#{id[0..7]}" # Use first 8 chars of UUID for uniqueness
  end
end

