# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketSharesController < ApplicationController
  before_action :authenticate_and_authorize!
  before_action :set_ticket
  before_action :check_permissions

  def index
    @shares = @ticket.shares.includes(:shared_with, :shared_by).order(created_at: :desc)
    render json: { shares: @shares.map { |s| {
      id: s.id,
      user: s.shared_with&.fullname,
      shared_by_id: s.shared_by_id.to_s,
      shared_by_name: s.shared_by&.fullname,
      permissions: s.permissions,
      message: s.message,
      status: s.status,
      created_at: s.created_at,
      expires_at: s.expires_at,
    } } }
  end

  def create
    shared_with = User.find(params[:shared_with_id])
    
    # Check if share already exists
    existing_share = @ticket.shares.find_by(shared_with_id: shared_with.id, status: 'active')
    if existing_share
      render json: { error: "You have already shared this ticket with #{shared_with.fullname}" }, status: :unprocessable_entity
      return
    end

    # Use permitted parameters
    attrs = share_params.to_h
    attrs[:shared_with] = shared_with
    attrs[:shared_by] = current_user
    
    # Debug permissions
    Rails.logger.info "Share create - Raw permissions: #{params[:permissions].inspect}"
    Rails.logger.info "Share create - Permitted permissions: #{attrs[:permissions].inspect}"
    
    attrs[:permissions] = Array(attrs[:permissions]).map(&:to_s) if attrs[:permissions].present?
    attrs[:permissions] ||= ['read']  # Default to read if no permissions specified
    attrs[:status] = 'active'
    
    Rails.logger.info "Share create - Final permissions: #{attrs[:permissions].inspect}"

    share = @ticket.shares.create!(attrs)

    # Notify the shared user with a link to the ticket (ensures click opens ticket)
    OnlineNotification.add(
      type:          'Ticket shared with you',
      object:        'Ticket',
      o_id:          @ticket.id,
      seen:          false,
      user_id:       shared_with.id,
      created_by_id: current_user.id,
    ) rescue nil

    # Real-time updates
    begin
      @ticket.touch
      @ticket.reload
      Sessions.broadcast({ event: 'Ticket:update', data: { id: @ticket.id, updated_at: @ticket.updated_at } }, 'authenticated')
      Sessions.broadcast({ event: 'Ticket:touch',  data: { id: @ticket.id, updated_at: @ticket.updated_at } }, 'authenticated')
      Sessions.broadcast({ event: 'TicketShare:create', data: { ticket_id: @ticket.id, share_id: share.id } }, 'authenticated')
    rescue StandardError
    end

    render json: { share: {
      id: share.id,
      user: share.shared_with&.fullname,
      permissions: share.permissions,
      message: share.message,
      status: share.status,
      created_at: share.created_at,
      expires_at: share.expires_at,
    } }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def revoke
    share = @ticket.shares.find(params[:id])
    
    # Only the person who shared or admin can revoke
    unless share.shared_by == current_user || current_user.role?('Admin')
      render json: { error: 'You can only revoke shares you created' }, status: :forbidden
      return
    end

    begin
      share.revoke!
      
      # Notify the shared user about revocation
      OnlineNotification.add(
        type:          'Share revoked',
        object:        'Ticket',
        o_id:          @ticket.id,
        seen:          false,
        user_id:       share.shared_with_id,
        created_by_id: current_user.id,
      )
    rescue StandardError => e
      render json: { error: "Failed to revoke share: #{e.message}" }, status: :unprocessable_entity
      return
    end

    # Real-time updates
    begin
      @ticket.touch
      @ticket.reload
      Sessions.broadcast({ event: 'Ticket:update', data: { id: @ticket.id, updated_at: @ticket.updated_at } }, 'authenticated')
      Sessions.broadcast({ event: 'Ticket:touch',  data: { id: @ticket.id, updated_at: @ticket.updated_at } }, 'authenticated')
      Sessions.broadcast({ event: 'TicketShare:update', data: { ticket_id: @ticket.id, share_id: share.id, action: 'revoke' } }, 'authenticated')
    rescue StandardError
    end

    render json: { share: {
      id: share.id,
      user: share.shared_with&.fullname,
      permissions: share.permissions,
      message: share.message,
      status: share.status,
      created_at: share.created_at,
      expires_at: share.expires_at,
    } }
  end

  def update
    share = @ticket.shares.find(params[:id])

    # Only the person who shared or admin can update
    unless share.shared_by == current_user || current_user.role?('Admin')
      render json: { error: 'You can only update shares you created' }, status: :forbidden
      return
    end

    # Use permitted parameters
    attrs = share_params.to_h
    attrs[:permissions] = Array(attrs[:permissions]).map(&:to_s) if attrs[:permissions].present?

    share.update!(attrs)

    # Notify shared user about update
    begin
      OnlineNotification.add(
        type:          'Share updated',
        object:        'Ticket',
        o_id:          @ticket.id,
        seen:          false,
        user_id:       share.shared_with_id,
        created_by_id: current_user.id,
      ) if share.shared_with_id.present?
    rescue StandardError
    end

    # Real-time updates
    begin
      @ticket.touch
      @ticket.reload
      Sessions.broadcast({ event: 'Ticket:update', data: { id: @ticket.id, updated_at: @ticket.updated_at } }, 'authenticated')
      Sessions.broadcast({ event: 'Ticket:touch',  data: { id: @ticket.id, updated_at: @ticket.updated_at } }, 'authenticated')
      Sessions.broadcast({ event: 'TicketShare:update', data: { ticket_id: @ticket.id, share_id: share.id, action: 'update' } }, 'authenticated')
    rescue StandardError
    end

    render json: { share: {
      id: share.id,
      user: share.shared_with&.fullname,
      permissions: share.permissions,
      message: share.message,
      status: share.status,
      created_at: share.created_at,
      expires_at: share.expires_at,
    } }
  end

  def destroy
    share = @ticket.shares.find(params[:id])
    
    # Only the person who shared or admin can delete
    unless share.shared_by == current_user || current_user.role?('Admin')
      render json: { error: 'You can only delete shares you created' }, status: :forbidden
      return
    end

    begin
      share.destroy!

      # Real-time updates
      begin
        @ticket.touch
        @ticket.reload
        Sessions.broadcast({ event: 'Ticket:update', data: { id: @ticket.id, updated_at: @ticket.updated_at } }, 'authenticated')
        Sessions.broadcast({ event: 'Ticket:touch',  data: { id: @ticket.id, updated_at: @ticket.updated_at } }, 'authenticated')
        Sessions.broadcast({ event: 'TicketShare:destroy', data: { ticket_id: @ticket.id, share_id: share.id } }, 'authenticated')
      rescue StandardError
      end

      render json: { success: true }
    rescue ActiveRecord::RecordNotDestroyed => e
      render json: { error: "Failed to delete share: #{e.message}" }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { error: "An error occurred: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
  end

  def check_permissions
    # Check if user can access the ticket (same as show action)
    authorize!(@ticket, :show?)
  end

  def share_params
    params.permit(:shared_with_id, :message, :expires_at, permissions: [])
  end
end
