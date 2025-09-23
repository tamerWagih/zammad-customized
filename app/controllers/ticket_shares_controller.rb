# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketSharesController < ApplicationController
  before_action :authenticate_and_authorize!
  before_action :set_ticket
  before_action :check_permissions

  def index
    @shares = @ticket.shares.includes(:shared_with, :shared_by).order(created_at: :desc)
    render json: { shares: @shares.map(&:as_json) }
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
      permissions: params[:permissions] || ['read'],
      message: params[:message],
      expires_at: params[:expires_at],
      status: 'active'
    )

    render json: { share: share.as_json }, status: :created
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
    render json: { share: share.as_json }
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
