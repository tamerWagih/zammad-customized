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
    existing_share = @ticket.shares.find_by(shared_with_id: shared_with.id)
    if existing_share
      render json: { error: 'Share already exists for this user' }, status: :unprocessable_entity
      return
    end

    share = @ticket.shares.create!(
      shared_with: shared_with,
      shared_by: current_user,
      permissions: (params[:permissions] || ['read']).map(&:to_s),
      message: params[:message],
      expires_at: params[:expires_at],
      status: 'active'
    )

    # Notify the shared user with a link to the ticket
    OnlineNotification.add(
      type:          'Ticket shared with you',
      object:        'Ticket',
      o_id:          @ticket.id,
      seen:          false,
      user_id:       shared_with.id,
      created_by_id: current_user.id,
    ) rescue nil

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

    share.revoke!

    # Optionally notify the shared user about revocation
    begin
      OnlineNotification.add(
        type:          'Share revoked',
        object:        'Ticket',
        o_id:          @ticket.id,
        seen:          false,
        user_id:       share.shared_with_id,
        created_by_id: current_user.id,
      )
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

    share.destroy
    render json: { success: true }
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
  end

  def check_permissions
    # Check if user can access the ticket (same as show action)
    authorize!(@ticket, :show?)
  end
end
