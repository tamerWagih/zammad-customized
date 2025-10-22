# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Tickets::CcController < ApplicationController
  before_action :authenticate_and_authorize!
  before_action :set_ticket
  before_action :check_permissions
  before_action :set_cc, only: %i[update destroy]

  def index
    ccs = @ticket.ccs.includes(:user, :created_by, :updated_by)
    render json: { ccs: ccs.map { |cc| serialize_cc(cc) } }
  end

  def create
    cc = @ticket.ccs.build(cc_params)
    cc.created_by = current_user

    if cc.save
      notify_user(
        user_id: cc.user_id,
        notification: 'cc'  # ✅ Fixed: Use 'cc' notification type
      )

      render json: { cc: serialize_cc(cc) }, status: :created
    else
      render json: { errors: cc.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: __('User not found') }, status: :not_found
  rescue Exceptions::UnprocessableEntity => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    @cc.updated_by = current_user

    if @cc.update(cc_params)
      notify_user(
        user_id: @cc.user_id,
        notification: 'cc'  # ✅ Fixed: Use 'cc' notification type
      )

      render json: { cc: serialize_cc(@cc) }
    else
      render json: { errors: @cc.errors }, status: :unprocessable_entity
    end
  rescue Exceptions::UnprocessableEntity => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    serialized = serialize_cc(@cc)
    
    @cc.destroy

    notify_user(
      user_id: serialized[:user_id],
      notification: 'cc'  # ✅ Fixed: Use 'cc' notification type
    )

    render json: { success: true, cc: serialized }
  rescue ActiveRecord::RecordNotDestroyed => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
  end

  def set_cc
    @cc = @ticket.ccs.find(params[:id])
  end

  def check_permissions
    authorize!(@ticket, :show?)
  end

  def cc_params
    params.permit(:user_id, :permissions, :message)
  end

  def serialize_cc(cc)
    user_id = cc.respond_to?(:user_id) ? cc.user_id : cc[:user_id]

    {
      id: stringify_id(cc[:id] || cc.id),
      ticket_id: stringify_id(cc[:ticket_id] || cc.ticket_id),
      user_id: stringify_id(user_id),
      user_name: cc.respond_to?(:user_name) ? cc.user_name : cc[:user_name],
      permissions: cc[:permissions] || cc.permissions,
      message: cc[:message] || cc.message,
      created_at: cc[:created_at] || cc.created_at,
      updated_at: cc[:updated_at] || cc.updated_at
    }
  end

  def notify_user(user_id:, notification:)
    return if user_id.blank?
    return if current_user && user_id.to_s == current_user.id.to_s

    OnlineNotification.add(
      type: notification,
      object: 'Ticket',
      o_id: @ticket.id,
      seen: false,
      user_id: user_id,
      created_by_id: current_user.id,
    )
  rescue StandardError
    nil
  end

  def stringify_id(value)
    value.present? ? value.to_s : nil
  end
end
