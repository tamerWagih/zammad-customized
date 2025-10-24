# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Dedicated controller for custom filter selector previews
# This isolates custom filter functionality from core SelectorsController
class CustomFilterSelectorsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # POST /api/v1/custom_filter_selectors/preview
  def preview
    Rails.logger.info "[CUSTOM_FILTER_PREVIEW] ===== START ====="
    Rails.logger.info "[CUSTOM_FILTER_PREVIEW] User: #{current_user&.id} (#{current_user&.login})"
    Rails.logger.info "[CUSTOM_FILTER_PREVIEW] Object: #{params[:object]}"
    
    # Only allow ticket selectors for custom filters
    if params[:object] != 'tickets'
      Rails.logger.error "[CUSTOM_FILTER_PREVIEW] Invalid object type: #{params[:object]}"
      raise Exceptions::UnprocessableEntity, __('Only ticket selectors are supported')
    end

    # Convert ActionController::Parameters to hash
    condition = params[:condition].to_h rescue {}
    Rails.logger.info "[CUSTOM_FILTER_PREVIEW] Condition: #{condition.inspect}"
    
    # Handle empty or invalid conditions gracefully
    if condition.blank? || !has_valid_conditions?(condition)
      Rails.logger.warn "[CUSTOM_FILTER_PREVIEW] Empty or invalid conditions"
      return render json: {
        object_ids:   [],
        object_count: 0,
        assets:       {},
      }
    end
    
    # Use Ticket.selectors (like admin does) with custom filter context
    # This method handles everything: sql generation, scopes, transactions
    Rails.logger.info "[CUSTOM_FILTER_PREVIEW] Calling Ticket.selectors with custom_filter_context"
    
    ticket_count, ticket_results = Ticket.selectors(
      condition,
      limit: 6,
      current_user: current_user,
      custom_filter_context: true,  # Enable custom filter attributes
      access: 'full'  # Use full access like overviews
    )
    
    Rails.logger.info "[CUSTOM_FILTER_PREVIEW] Got #{ticket_count} total, #{ticket_results&.length || 0} results"
    
    tickets = []
    assets = {}
    
    ticket_results&.each do |ticket|
      tickets.push ticket.id
      assets = ticket.assets(assets)
    end

    Rails.logger.info "[CUSTOM_FILTER_PREVIEW] Found #{ticket_count} tickets (showing #{tickets.length})"
    Rails.logger.info "[CUSTOM_FILTER_PREVIEW] ===== SUCCESS ====="
    
    render json: {
      object_ids:   tickets,
      object_count: ticket_count,
      assets:       assets,
    }
  rescue => e
    Rails.logger.error "[CUSTOM_FILTER_PREVIEW] ===== ERROR ====="
    Rails.logger.error "[CUSTOM_FILTER_PREVIEW] #{e.class}: #{e.message}"
    Rails.logger.error "[CUSTOM_FILTER_PREVIEW] Backtrace:"
    Rails.logger.error e.backtrace.join("\n")
    
    render json: {
      error: __('Error previewing selector'),
      error_detail: e.message,
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


