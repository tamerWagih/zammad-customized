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

    # Get condition - Rails automatically parses JSON body into params
    # Pass condition directly like SelectorsController does
    condition = params[:condition]

    raise Exceptions::UnprocessableEntity, __('Invalid condition') if condition.blank?

    # Use Ticket.selectors with custom filter context
    # This method handles everything: sql generation, scopes, transactions
    Rails.logger.info "Custom filter preview: condition=#{condition.inspect}, current_user=#{current_user.id}"
    
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

end


