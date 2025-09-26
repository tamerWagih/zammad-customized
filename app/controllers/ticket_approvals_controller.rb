# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketApprovalsController < ApplicationController
  before_action :authenticate_and_authorize!
  before_action :set_ticket
  before_action :check_permissions

  def index
    @approvals = @ticket.approvals.includes(:approver, :requester).order(created_at: :desc)
    render json: { approvals: @approvals.map { |a| {
      id: a.id,
      status: a.status,
      message: a.message,
      priority: a.priority,
      approver: a.approver&.fullname,
      approver_id: a.approver_id.to_s,
      requester: a.requester&.fullname,
      requester_id: a.requester_id.to_s,
      created_at: a.created_at,
    } } }
  end

  def create
    approver = User.find(params[:approver_id])
    
    # Check if approval already exists
    existing_approval = @ticket.approvals.find_by(approver_id: approver.id, status: 'pending')
    if existing_approval
      render json: { error: "You have already sent an approval request to #{approver.fullname}" }, status: :unprocessable_entity
      return
    end

    approval = @ticket.approvals.create!(
      approver: approver,
      requester: current_user,
      message: params[:message],
      priority: params[:priority].presence || 'normal',
      status: 'pending'
    )

    # Notify approver with a link to the ticket (ensures click opens ticket)
    OnlineNotification.add(
      type:          'Approval request',
      object:        'Ticket',
      o_id:          @ticket.id,
      seen:          false,
      user_id:       approver.id,
      created_by_id: current_user.id,
    ) rescue nil

    render json: { approval: {
      id: approval.id,
      status: approval.status,
      message: approval.message,
      priority: approval.priority,
      approver: approval.approver&.fullname,
      created_at: approval.created_at,
    } }, status: :created
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

    # Notify requester about decision
    begin
      OnlineNotification.add(
        type:          'Approval approved',
        object:        'Ticket',
        o_id:          @ticket.id,
        seen:          false,
        user_id:       approval.requester_id,
        created_by_id: current_user.id,
      ) if approval.requester_id.present?
    rescue StandardError
    end

    render json: { approval: {
      id: approval.id,
      status: approval.status,
      message: approval.message,
      priority: approval.priority,
      approver: approval.approver&.fullname,
      created_at: approval.created_at,
    } }
  end

  def reject
    approval = @ticket.approvals.find(params[:id])
    
    unless approval.approver == current_user
      render json: { error: 'You can only reject requests assigned to you' }, status: :forbidden
      return
    end

    approval.reject!

    # Notify requester about decision
    begin
      OnlineNotification.add(
        type:          'Approval rejected',
        object:        'Ticket',
        o_id:          @ticket.id,
        seen:          false,
        user_id:       approval.requester_id,
        created_by_id: current_user.id,
      ) if approval.requester_id.present?
    rescue StandardError
    end

    render json: { approval: {
      id: approval.id,
      status: approval.status,
      message: approval.message,
      priority: approval.priority,
      approver: approval.approver&.fullname,
      created_at: approval.created_at,
    } }
  end

  def update
    approval = @ticket.approvals.find(params[:id])
    
    # Only the requester can edit pending requests
    unless approval.requester == current_user
      render json: { error: 'You can only edit your own approval requests' }, status: :forbidden
      return
    end

    # Only allow editing pending requests
    unless approval.status == 'pending'
      render json: { error: 'You can only edit pending approval requests' }, status: :unprocessable_entity
      return
    end

    # Update the approval
    approval.update!(
      message: approval_params[:message],
      priority: approval_params[:priority].presence || 'normal'
    )

    # Notify approver about the edit
    begin
      OnlineNotification.add(
        type:          'Approval request updated',
        object:        'Ticket',
        o_id:          @ticket.id,
        seen:          false,
        user_id:       approval.approver_id,
        created_by_id: current_user.id,
      ) if approval.approver_id.present?
    rescue StandardError
    end

    render json: { approval: {
      id: approval.id,
      status: approval.status,
      message: approval.message,
      priority: approval.priority,
      approver: approval.approver&.fullname,
      created_at: approval.created_at,
    } }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: "An error occurred: #{e.message}" }, status: :internal_server_error
  end

  def destroy
    approval = @ticket.approvals.find(params[:id])
    
    # Only the requester or admin can delete
    unless approval.requester == current_user || current_user.role?('Admin')
      render json: { error: 'You can only delete your own approval requests' }, status: :forbidden
      return
    end

    begin
      # Notify approver about deletion if they haven't responded yet
      if approval.status == 'pending' && approval.approver_id.present?
        begin
          OnlineNotification.add(
            type:          'Approval request deleted',
            object:        'Ticket',
            o_id:          @ticket.id,
            seen:          false,
            user_id:       approval.approver_id,
            created_by_id: current_user.id,
          )
        rescue StandardError
        end
      end
      
      approval.destroy!
      render json: { success: true }
    rescue ActiveRecord::RecordNotDestroyed => e
      render json: { error: "Failed to delete approval: #{e.message}" }, status: :unprocessable_entity
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

  def approval_params
    params.require(:approval).permit(:message, :priority)
  end
end
