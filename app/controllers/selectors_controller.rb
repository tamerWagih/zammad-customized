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
    
    # Skip processing if condition is empty or has no valid conditions
    if condition.blank? || !has_valid_conditions?(condition)
      return render json: {
        object_ids:   [],
        object_count: 0,
        assets:       {},
      }
    end
    
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

  def has_valid_conditions?(condition)
    return false if condition.blank?
    
    condition.any? do |key, value|
      next false if value.blank?
      
      # Check if condition has valid values
      if value.is_a?(Hash) && value.key?('value')
        # Valid if value is not empty array
        !(value['value'].is_a?(Array) && value['value'].empty?)
      else
        true
      end
    end
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
