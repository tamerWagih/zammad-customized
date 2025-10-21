# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Dedicated controller for custom filter selector previews
# This isolates custom filter functionality from core SelectorsController
class CustomFilterSelectorsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # POST /api/v1/custom_filter_selectors/preview
  def preview
    # Only allow ticket selectors for custom filters
    raise Exceptions::UnprocessableEntity, __('Only ticket selectors are supported') if params[:object] != 'tickets'

    condition = params[:condition] || {}
    
    # Handle empty or invalid conditions gracefully
    if condition.blank? || !has_valid_conditions?(condition)
      return render json: {
        object_ids:   [],
        object_count: 0,
        assets:       {},
      }
    end
    
    # Use Ticket.selector2sql with custom filter context
    # This ensures custom attributes (shared_with_me, approval_status, etc.) work
    query, bind_params = Ticket.selector2sql(
      condition, 
      current_user: current_user,
      custom_filter_context: true  # Mark this as custom filter context
    )
    
    tickets = []
    assets = {}
    ticket_count = 0
    
    if query.present?
      # Get tickets with proper permission filtering (selector2sql handles this)
      ticket_results = Ticket.where(query, *bind_params).limit(6)
      ticket_count = Ticket.where(query, *bind_params).count
      
      ticket_results.each do |ticket|
        tickets.push ticket.id
        assets = ticket.assets(assets)
      end
    end

    render json: {
      object_ids:   tickets,
      object_count: ticket_count,
      assets:       assets,
    }
  rescue => e
    Rails.logger.error "Custom filter selector preview error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    render json: {
      error: __('Error previewing selector'),
      object_ids:   [],
      object_count: 0,
      assets:       {},
    }, status: :unprocessable_entity
  end

  private

  def has_valid_conditions?(condition)
    return false if condition.blank?
    
    # Check if at least one condition has valid values
    condition.any? do |key, value|
      next false if value.blank?
      
      # Check for valid condition structure
      if value.is_a?(Hash) && value.key?('value')
        # Valid if value is not empty array
        !(value['value'].is_a?(Array) && value['value'].empty?)
      else
        true
      end
    end
  end
end

