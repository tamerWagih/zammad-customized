# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class SelectorsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!
  before_action         :ensure_object_klass_has_selector!

  # POST /api/v1/:object/selector
  # POST /api/v1/tickets/selector
  # POST /api/v1/users/selector
  # POST /api/v1/organizations/selector
  def preview
    # Handle case where no condition is provided (empty selector)
    condition = params[:condition] || {}
    
    # Filter out conditions with empty value arrays to prevent InvalidCondition errors
    condition = filter_empty_conditions(condition)
    
    object_count, objects = object_klass.selectors(condition, limit: 6, execution_time: true)

    assets     = {}
    object_ids = []
    objects&.each do |object|
      object_ids.push object.id
      assets = object.assets(assets)
    end

    # return result
    render json: {
      object_ids:   object_ids,
      object_count: object_count || 0,
      assets:       assets,
    }
  end

  private

  def filter_empty_conditions(condition)
    return condition if condition.blank?
    
    filtered = {}
    condition.each do |key, value|
      next if value.blank?
      
      # Handle nested condition objects
      if value.is_a?(Hash) && value.key?('value')
        # Skip conditions with empty value arrays
        next if value['value'].is_a?(Array) && value['value'].empty?
      end
      
      filtered[key] = value
    end
    
    filtered
  end

  def object_klass
    @object_klass ||= case params[:object]
                      when 'organizations'
                        Organization
                      when 'tickets'
                        Ticket
                      when 'users'
                        User
                      end
  end

  def ensure_object_klass_has_selector!
    return if object_klass.present?

    raise Exceptions::UnprocessableEntity, __('Given object does not support selector')
  end
end
