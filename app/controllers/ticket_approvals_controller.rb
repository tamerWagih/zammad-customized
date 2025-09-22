# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketApprovalsController < ApplicationController
  before_action :authenticate_and_authorize!
  before_action :set_ticket
  before_action :check_permissions

  def index
    @approvals = @ticket.approvals.includes(:approver, :requester).order(created_at: :desc)
    render json: { approvals: @approvals.map(&:as_json) }
  end

  def create
    approver = User.find(params[:approver_id])
    
    # Check if approval already exists
    existing_approval = @ticket.approvals.find_by(approver_id: approver.id)
    if existing_approval
      render json: { error: 'Approval request already exists for this approver' }, status: :unprocessable_entity
      return
    end

    approval = @ticket.approvals.create!(
      approver: approver,
      requester: current_user,
      message: params[:message],
      priority: params[:priority] || 'normal',
      status: 'pending'
    )

    render json: { approval: approval.as_json }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Approver not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def approve
    approval = @ticket.approvals.find(params[:id])
    
    unless approval.approver == current_user
      render json: { error: 'You can only approve requests assigned to you' }, status: :forbidden
      return
    end

    approval.approve!
    render json: { approval: approval.as_json }
  end

  def reject
    approval = @ticket.approvals.find(params[:id])
    
    unless approval.approver == current_user
      render json: { error: 'You can only reject requests assigned to you' }, status: :forbidden
      return
    end

    approval.reject!
    render json: { approval: approval.as_json }
  end

  def destroy
    approval = @ticket.approvals.find(params[:id])
    
    # Only the requester or admin can delete
    unless approval.requester == current_user || current_user.role?('Admin')
      render json: { error: 'You can only delete your own approval requests' }, status: :forbidden
      return
    end

    approval.destroy
    render json: { success: true }
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
  end

  def check_permissions
    # Check if user can access the ticket (same as show action)
    authorize!(@ticket, :show)
  end
end
