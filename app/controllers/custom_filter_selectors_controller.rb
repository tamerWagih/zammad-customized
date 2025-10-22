# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Dedicated controller for custom filter selector previews
# This isolates custom filter functionality from core SelectorsController
class CustomFilterSelectorsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # POST /api/v1/custom_filter_selectors/preview
  def preview
    # Only allow ticket selectors for custom filters
    raise Exceptions::UnprocessableEntity, __('Only ticket selectors are supported') if params[:object] != 'tickets'

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
    
    # Use Ticket.selector2sql with custom filter context
    # This ensures custom attributes (shared_with_me, approval_status, etc.) work
    query, bind_params, tables = Ticket.selector2sql(
      condition, 
      current_user: current_user,
      custom_filter_context: true  # Mark this as custom filter context
    )
    
    tickets = []
    assets = {}
    ticket_count = 0
    
    if query.present?
      # Apply user permission scope first (like Zammad's overview system)
      # Use OverviewScope for standard conditions, ReadScope for mentions
      base_scope = if condition.key?('ticket.mention_user_ids')
                     TicketPolicy::ReadScope.new(current_user).resolve
                   else
                     TicketPolicy::OverviewScope.new(current_user).resolve
                   end
      
      # Apply the custom filter condition on top of permission scope
      scoped_tickets = base_scope.where(query, *bind_params)
      scoped_tickets = scoped_tickets.joins(tables) if tables.present?
      
      ticket_results = scoped_tickets.limit(6)
      ticket_count = scoped_tickets.count
      
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


