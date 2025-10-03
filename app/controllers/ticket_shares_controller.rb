# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketSharesController < ApplicationController
  before_action :authenticate_and_authorize!
  before_action :set_ticket
  before_action :check_permissions

  def index
    # Only show active shares, or all shares for the person who created them (for management)
    @shares = @ticket.shares.includes(:shared_with, :shared_by).where(
      "status = 'active' OR shared_by_id = ?", current_user.id
    ).order(created_at: :desc)
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
      render json: { 
        error: "This ticket is already shared with #{shared_with.fullname}. Please use the edit option to modify the existing share.",
        existing_share: {
          id: existing_share.id,
          permissions: existing_share.permissions,
          message: existing_share.message,
          expires_at: existing_share.expires_at,
        }
      }, status: :unprocessable_entity
      return
    end

    # Process permissions like approval does - directly from params
    permissions = Array(params[:permissions]).map(&:to_s) if params[:permissions].present?
    permissions ||= ['read']  # Default to read if no permissions specified
    
    # Create share directly like approval does
    share = @ticket.shares.create!(
      shared_with: shared_with,
      shared_by: current_user,
      message: params[:message],
      expires_at: params[:expires_at],
      permissions: permissions,
      status: 'active'
    )
    

    # Notify the shared user with a link to the ticket (ensures click opens ticket)
    OnlineNotification.add(
      type:          'Ticket shared with you',
      object:        'Ticket',
      o_id:          @ticket.id,
      seen:          false,
      user_id:       shared_with.id,
      created_by_id: current_user.id,
    ) rescue nil

    # Real-time updates are handled automatically by Ticket::Share::TriggersSubscriptions

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

    # Real-time updates are handled automatically by Ticket::Share::TriggersSubscriptions

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

    # Real-time updates are handled automatically by Ticket::Share::TriggersSubscriptions

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
      # Store share data before deletion for frontend event
      share_data = {
        id: share.id,
        user: share.shared_with&.fullname,
        permissions: share.permissions,
        message: share.message,
        status: share.status,
        created_at: share.created_at,
        expires_at: share.expires_at,
      }
      
      # Notify the shared user before deleting
      OnlineNotification.add(
        type: 'Share Deleted',
        object: 'Ticket',
        o_id: @ticket.id,
        user_id: share.shared_with_id,
        created_by_id: current_user.id,
        updated_by_id: current_user.id
      )

      share.destroy!

      # Real-time updates are handled automatically by Ticket::Share::TriggersSubscriptions

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
