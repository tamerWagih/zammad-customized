# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketSharesController < ApplicationController
  before_action :authenticate_and_authorize!
  before_action :set_ticket
  before_action :check_permissions
  before_action :set_share, only: %i[revoke update destroy]

  def index
    shares = Service::Ticket::Share::List
      .new(current_user:)
      .execute(ticket: @ticket)

    render json: { shares: shares.map { |share| serialize_share(share) } }
  end

  def create
    share = Service::Ticket::Share::Create
      .new(current_user:)
      .execute(
        ticket:          @ticket,
        shared_with_id:  share_create_params[:shared_with_id],
        permissions:     share_create_params[:permissions],
        message:         share_create_params[:message],
        expires_at:      share_create_params[:expires_at]
      )

    notify_shared_user(share, 'Ticket shared with you')

    render json: { share: serialize_share(share) }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: __('User not found') }, status: :not_found
  rescue Exceptions::UnprocessableEntity => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def revoke
    share = Service::Ticket::Share::Revoke
      .new(current_user:)
      .execute(share: @share)

    notify_shared_user(share, 'Share revoked')

    render json: { share: serialize_share(share) }
  rescue Exceptions::Forbidden => e
    render json: { error: e.message }, status: :forbidden
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    share = Service::Ticket::Share::Update
      .new(current_user:)
      .execute(share: @share, attributes: share_update_params)

    notify_shared_user(share, 'Share updated') if share.shared_with_id.present?

    render json: { share: serialize_share(share) }
  rescue Exceptions::Forbidden => e
    render json: { error: e.message }, status: :forbidden
  rescue Exceptions::UnprocessableEntity => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    share_data = Service::Ticket::Share::Destroy
      .new(current_user:)
      .execute(share: @share)

    notify_shared_user(share_data, 'Share revoked')

    render json: { success: true, share: serialize_share(share_data) }
  rescue Exceptions::Forbidden => e
    render json: { error: e.message }, status: :forbidden
  rescue ActiveRecord::RecordNotDestroyed => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
  end

  def set_share
    @share = @ticket.shares.find(params[:id])
  end

  def check_permissions
    authorize!(@ticket, :show?)
  end

  def share_create_params
    params.permit(:shared_with_id, :message, :expires_at, permissions: [])
  end

  def share_update_params
    params.permit(:message, :expires_at, permissions: [])
  end

  def serialize_share(share)
    shared_with_id = share.respond_to?(:shared_with_id) ? share.shared_with_id : share[:shared_with_id]
    shared_by_id   = share.respond_to?(:shared_by_id) ? share.shared_by_id : share[:shared_by_id]
    shared_with_name = share.respond_to?(:shared_with) ? share.shared_with&.fullname : share[:shared_with_name]
    shared_by_name   = share.respond_to?(:shared_by) ? share.shared_by&.fullname : share[:shared_by_name]

    {
      id:               stringify_id(share[:id] || share.id),
      ticket_id:        stringify_id(share[:ticket_id] || share.ticket_id),
      shared_with_id:   stringify_id(shared_with_id),
      shared_with_name: shared_with_name,
      user:             shared_with_name,
      shared_by_id:     stringify_id(shared_by_id),
      shared_by_name:   shared_by_name,
      permissions:      Array(share[:permissions] || share.permissions),
      message:          share[:message] || share.message,
      status:           share[:status] || share.status,
      created_at:       share[:created_at] || share.created_at,
      updated_at:       share[:updated_at] || share.updated_at,
      expires_at:       share[:expires_at] || share.expires_at
    }
  end

  def notify_shared_user(share_data, notification_type)
    shared_with_id = if share_data.respond_to?(:shared_with_id)
                       share_data.shared_with_id
                     else
                       share_data[:shared_with_id]
                     end

    return if shared_with_id.blank?

    OnlineNotification.add(
      type:          notification_type,
      object:        'Ticket',
      o_id:          @ticket.id,
      seen:          false,
      user_id:       shared_with_id,
      created_by_id: current_user.id,
    )
  rescue StandardError
    nil
  end

  def stringify_id(value)
    value.present? ? value.to_s : nil
  end
end

