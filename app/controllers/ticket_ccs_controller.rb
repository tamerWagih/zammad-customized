# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketCcsController < ApplicationController
  before_action :authenticate_and_authorize!
  before_action :set_ticket
  before_action :check_permissions
  before_action :set_cc, only: %i[update destroy]

  def index
    ccs = Service::Ticket::Cc::List
      .new(current_user:)
      .execute(ticket: @ticket)

    render json: { ticketCcs: ccs.map { |cc| serialize_cc(cc) } }
  end

  def create
    cc = Service::Ticket::Cc::Create
      .new(current_user:)
      .execute(
        ticket:   @ticket,
        user_id:  cc_create_params[:user_id],
        message:  cc_create_params[:message]
      )

    notify_cc_user(cc, __('You have been CC\'d on a ticket'))

    render json: { ticketCc: serialize_cc(cc) }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: __('User not found') }, status: :not_found
  rescue Exceptions::UnprocessableEntity => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    cc = Service::Ticket::Cc::Update
      .new(current_user:)
      .execute(cc: @cc, attributes: cc_update_params)

    notify_cc_user(cc, __('CC record updated'))

    render json: { ticketCc: serialize_cc(cc) }
  rescue Exceptions::Forbidden => e
    render json: { error: e.message }, status: :forbidden
  rescue Exceptions::UnprocessableEntity => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    cc_data = Service::Ticket::Cc::Destroy
      .new(current_user:)
      .execute(cc: @cc)

    notify_cc_user(cc_data, __('You have been removed from CC'))

    render json: { success: true, ticketCc: serialize_cc(cc_data) }
  rescue Exceptions::Forbidden => e
    render json: { error: e.message }, status: :forbidden
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

  def cc_create_params
    params.permit(:user_id, :message)
  end

  def cc_update_params
    params.permit(:message, permissions: [])
  end

  def serialize_cc(cc)
    user_id = extract_attribute(cc, :user_id)
    user_name = extract_attribute(cc, :user_name) || cc.try(:user)&.fullname

    {
      id:             stringify_id(extract_attribute(cc, :id)),
      ticket_id:      stringify_id(extract_attribute(cc, :ticket_id)),
      user_id:        stringify_id(user_id),
      user_name:      user_name,
      user:           user_name,
      permissions:    Array(extract_attribute(cc, :permissions)),
      message:        extract_attribute(cc, :message),
      created_by_id:  stringify_id(extract_attribute(cc, :created_by_id)),
      created_by_name: cc.respond_to?(:created_by) ? cc.created_by&.fullname : cc[:created_by_name],
      createdAt:      extract_attribute(cc, :created_at),
      updatedAt:      extract_attribute(cc, :updated_at)
    }
  end

  def notify_cc_user(cc_data, notification_type)
    user_id = extract_attribute(cc_data, :user_id)
    return if user_id.blank?
    return if current_user && user_id.to_s == current_user.id.to_s

    OnlineNotification.add(
      type:          notification_type,
      object:        'Ticket',
      o_id:          @ticket.id,
      seen:          false,
      user_id:       user_id,
      created_by_id: current_user.id,
    )
  rescue StandardError => e
    Rails.logger.warn "Failed to create CC notification: #{e.message}"
    nil
  end

  def extract_attribute(source, key)
    if source.respond_to?(key)
      source.public_send(key)
    elsif source.respond_to?(:[])
      source[key]
    end
  end

  def stringify_id(value)
    value.present? ? value.to_s : nil
  end
end

