# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Dedicated controller for custom filter selector previews
# This isolates custom filter functionality from core SelectorsController
class CustomFilterSelectorsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # POST /api/v1/custom_filter_selectors/preview
  def preview
    # Only allow ticket selectors for custom filters
    if params[:object] != 'tickets'
      raise Exceptions::UnprocessableEntity, __('Only ticket selectors are supported')
    end

    # Convert ActionController::Parameters to hash
    condition = params[:condition].to_h rescue {}
    
    # Handle empty or invalid conditions gracefully
    if condition.blank? || !has_valid_conditions?(condition)
      return render json: {
        object_ids:   [],
        object_count: 0,
        assets:       {},
      }
    end
    
    # Use Ticket.selectors (like admin does) with custom filter context
    # This method handles everything: sql generation, scopes, transactions
    Rails.logger.info "Preview: condition=#{condition.inspect}, current_user=#{current_user.id}"
    
    ticket_count, ticket_results = Ticket.selectors(
      condition,
      limit: 6,
      current_user: current_user,
      custom_filter_context: true,  # Enable custom filter attributes
      access: 'full'  # Use full access like overviews
    )
    
    Rails.logger.info "Preview: found #{ticket_count} tickets, results=#{ticket_results&.length}"
    
    tickets = []
    assets = {}
    
    ticket_results&.each do |ticket|
      tickets.push ticket.id
      assets = ticket.assets(assets)
    end
    
    render json: {
      object_ids:   tickets,
      object_count: ticket_count,
      assets:       assets,
    }
  rescue => e
    Rails.logger.error "Custom filter preview error: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    
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


