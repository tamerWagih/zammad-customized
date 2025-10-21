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
    # Extract and convert nested parameters to plain hashes BEFORE any database operations
    condition_hash = params[:condition].present? ? deep_to_hash(params[:condition]) : {}
    order_hash = params[:order].present? ? deep_to_hash(params[:order]) : { 'by' => 'created_at', 'direction' => 'DESC' }
    view_hash = params[:view].present? ? deep_to_hash(params[:view]) : { 's' => ['number', 'title', 'customer', 'state', 'created_at'] }
    group_by_value = params[:group_by].present? ? params[:group_by].to_s : ''
    name_value = params[:name].to_s
    prio_value = params[:prio].present? ? params[:prio].to_i : nil
    active_value = params[:active].nil? ? true : params[:active]
    
    # Initialize custom_filters if not exists
    current_user.preferences[:custom_filters] ||= []
    
    # Generate unique ID for the filter
    filter_id = SecureRandom.uuid
    
    # Build the filter object using plain Ruby hashes (not ActionController::Parameters)
    new_filter = {
      'id' => filter_id,
      'name' => name_value,
      'link' => generate_link(name_value, filter_id),
      'condition' => condition_hash,
      'order' => order_hash,
      'view' => view_hash,
      'group_by' => group_by_value,
      'prio' => prio_value || (current_user.preferences[:custom_filters].length + 1000),
      'active' => active_value,
      'is_custom' => true,
      'user_id' => current_user.id,
      'created_at' => Time.zone.now.iso8601,
      'updated_at' => Time.zone.now.iso8601
    }
    
    # Ensure we're working with a plain hash for preferences
    prefs = deep_to_hash(current_user.preferences) || {}
    prefs['custom_filters'] ||= []
    prefs['custom_filters'] << new_filter
    
    current_user.preferences = prefs
    
    if current_user.save
      # Reload to get clean data
      current_user.reload
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
    # Extract and convert nested parameters to plain hashes BEFORE any database operations
    condition_hash = params[:condition].present? ? deep_to_hash(params[:condition]) : nil
    order_hash = params[:order].present? ? deep_to_hash(params[:order]) : nil
    view_hash = params[:view].present? ? deep_to_hash(params[:view]) : nil
    group_by_value = params[:group_by].present? ? params[:group_by].to_s : nil
    name_value = params[:name].present? ? params[:name].to_s : nil
    prio_value = params[:prio].present? ? params[:prio].to_i : nil
    active_value = params.key?(:active) ? params[:active] : nil
    
    # Ensure we're working with plain hashes
    prefs = deep_to_hash(current_user.preferences) || {}
    custom_filters = prefs['custom_filters'] || []
    filter_index = custom_filters.find_index { |f| f['id'] == params[:id] }
    
    if filter_index.nil?
      render json: { error: 'Filter not found' }, status: :not_found
      return
    end
    
    filter = custom_filters[filter_index]
    
    # Update filter attributes using plain hashes
    filter['name'] = name_value if name_value.present?
    filter['condition'] = condition_hash if condition_hash
    filter['order'] = order_hash if order_hash
    filter['view'] = view_hash if view_hash
    filter['group_by'] = group_by_value unless group_by_value.nil?
    filter['prio'] = prio_value if prio_value
    filter['active'] = active_value unless active_value.nil?
    filter['updated_at'] = Time.zone.now.iso8601
    
    # Update link if name changed
    if name_value.present?
      filter['link'] = generate_link(name_value, filter['id'])
    end
    
    prefs['custom_filters'][filter_index] = filter
    current_user.preferences = prefs
    
    if current_user.save
      current_user.reload
      render json: filter
    else
      Rails.logger.error "Failed to update custom filter: #{current_user.errors.full_messages}"
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error updating custom filter: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  # DELETE /api/v1/user_custom_filters/:id
  def destroy
    # Ensure we're working with plain hashes
    prefs = deep_to_hash(current_user.preferences) || {}
    custom_filters = prefs['custom_filters'] || []
    filter_index = custom_filters.find_index { |f| f['id'] == params[:id] }
    
    if filter_index.nil?
      render json: { error: 'Filter not found' }, status: :not_found
      return
    end
    
    prefs['custom_filters'].delete_at(filter_index)
    current_user.preferences = prefs
    
    if current_user.save
      current_user.reload
      render json: { success: true }
    else
      Rails.logger.error "Failed to delete custom filter: #{current_user.errors.full_messages}"
      render json: { errors: current_user.errors.full_messages}, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error deleting custom filter: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: 'Internal server error' }, status: :internal_server_error
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

  # Recursively convert ActionController::Parameters to plain Hash
  def deep_to_hash(obj)
    case obj
    when ActionController::Parameters
      obj.to_unsafe_h.transform_values { |v| deep_to_hash(v) }
    when Hash
      obj.transform_values { |v| deep_to_hash(v) }
    when Array
      obj.map { |item| deep_to_hash(item) }
    else
      obj
    end
  end
end

