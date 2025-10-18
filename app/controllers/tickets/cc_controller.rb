# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Tickets::CcController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def index
    ticket = Ticket.find(params[:ticket_id])
    authorize!(ticket, :show?)

    ccs = ticket.ccs.includes(:user, :created_by, :updated_by)
    render json: ccs
  end

  def create
    ticket = Ticket.find(params[:ticket_id])
    authorize!(ticket, :update?)

    cc = ticket.ccs.build(cc_params)
    cc.created_by = current_user

    if cc.save
      render json: cc, status: :created
    else
      render json: { errors: cc.errors }, status: :unprocessable_entity
    end
  end

  def update
    ticket = Ticket.find(params[:ticket_id])
    authorize!(ticket, :update?)

    cc = ticket.ccs.find(params[:id])
    cc.updated_by = current_user

    if cc.update(cc_params)
      render json: cc
    else
      render json: { errors: cc.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    ticket = Ticket.find(params[:ticket_id])
    authorize!(ticket, :update?)

    cc = ticket.ccs.find(params[:id])
    cc.destroy

    head :no_content
  end

  private

  def cc_params
    params.require(:cc).permit(:user_id, :permissions, :message)
  end
end
