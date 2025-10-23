# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::AssetsAll
  attr_accessor :user, :ticket

  def initialize(user, ticket)
    @user = user
    @ticket = ticket
  end

  def all_assets(assets = {})
    attributes_to_change = get_attributes_to_change(assets)

    all_assets = compile_assets(attributes_to_change[:assets])

    response(all_assets, attributes_to_change)
  end

  private

  def compile_assets(assets)
    ticket.assets(assets)

    assets = ApplicationModel::CanAssets.reduce([ticket, articles, mentions].flatten, assets)
    assets = Link.reduce_assets(assets, links)

    if (draft = ticket.shared_draft) && Ticket::SharedDraftZoomPolicy.new(user, draft).show?
      assets = draft.assets(assets)
    end

    if Setting.get('checklist') && user.permissions?('ticket.agent')
      ticket.checklist&.assets(assets)

      ticket.referencing_checklists
        .includes(:ticket)
        .each do |elem|
          elem.assets(assets)
          elem.ticket.assets(assets) if elem.ticket.authorized_asset?
        end
    end

    assets
  end

  def response(assets, attributes_to_change)

    approvals_data = approvals
    shares_data = shares
    ccs_data = ccs
    share_perms = share_permissions


    response_data = {
      ticket_id:          ticket.id,
      ticket_article_ids: articles.pluck(:id),
      assets:             assets,
      links:              links,
      tags:               tags,
      mentions:           mentions.pluck(:id),
      time_accountings:   time_accountings,
      form_meta:          attributes_to_change[:form_meta],
      approvals:          approvals_data,
      shares:             shares_data,
      ccs:                ccs_data,
      share_permissions:  share_perms,
    }

    response_data
  end
  
  def share_permissions
    return { read: false, comment: false, edit: false } unless user
    
    begin
      if ticket.respond_to?(:share_permissions_for)
        ticket.share_permissions_for(user)
      else
        { read: false, comment: false, edit: false }
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to get share permissions for ticket #{ticket.id}, user #{user.id}: #{e.message}"
      { read: false, comment: false, edit: false }
    end
  end

  def get_attributes_to_change(assets)
    Ticket::ScreenOptions.attributes_to_change(
      current_user: user,
      ticket:       ticket,
      screen:       'edit',
      assets:       assets,
    )
  end

  def articles
    @articles ||= ticket.articles.filter { |elem| Ticket::ArticlePolicy.new(user, elem).show? }
  end

  def links
    @links ||= Link.list(
      link_object:       'Ticket',
      link_object_value: ticket.id,
      user:              user,
    )
  end

  def tags
    @tags ||= ticket.tag_list
  end

  def time_accountings
    @time_accountings = ticket
      .ticket_time_accounting
      .map { |row| row.slice(:id, :ticket_id, :ticket_article_id, :time_unit, :type_id) }
  end

  def mentions
    @mentions ||= ticket.mentions
  end

  def approvals
    @approvals ||= if ticket.respond_to?(:approvals) && user.permissions?('ticket.agent')
                     # Return all approvals for this ticket (same format as ApprovalController)
                     result = ticket.approvals.includes(:approver, :requester).map do |approval|
                       {
                         id:           approval.id.to_s,
                         ticket_id:    approval.ticket_id.to_s,
                         approver_id:  approval.approver_id.to_s,
                         approver:     approval.approver&.fullname,
                         requester_id: approval.requester_id.to_s,
                         requester:    approval.requester&.fullname,
                         status:       approval.status,
                         message:      approval.message,
                         priority:     approval.priority,
                         created_at:   approval.created_at,
                         updated_at:   approval.updated_at,
                       }
                     end
                     result
                   else
                     []
                   end
  end

  def shares
    @shares ||= if ticket.respond_to?(:shares) && user.permissions?('ticket.agent')
                  # Return all shares for this ticket (same format as SharesController)
                  result = ticket.shares.includes(:shared_by, :group).map do |share|
                    {
                      id:              share.id.to_s,
                      ticket_id:       share.ticket_id.to_s,
                      group_id:        share.group_id.to_s,
                      group_name:      share.group&.name,
                      group:           share.group&.name,
                      shared_by_id:    share.shared_by_id.to_s,
                      shared_by_name:  share.shared_by&.fullname,
                      status:          share.status,
                      permissions:     Array(share.permissions),
                      message:         share.message,
                      expires_at:      share.expires_at,
                      created_at:      share.created_at,
                      updated_at:      share.updated_at,
                    }
                  end
                  Rails.logger.info "[SHARE_API] Ticket ##{ticket.id}: Returning #{result.size} shares for user ##{user.id} (#{user.email})"
                  result
                else
                  Rails.logger.info "[SHARE_API] Ticket ##{ticket.id}: No shares returned (respond_to: #{ticket.respond_to?(:shares)}, is_agent: #{user.permissions?('ticket.agent')})"
                  []
                end
  end

  def ccs
    @ccs ||= if ticket.respond_to?(:ccs)
               # Return all CCs for this ticket (same format as CcController)
               result = ticket.ccs.includes(:user, :created_by).map do |cc|
                 {
                   id:          cc.id.to_s,
                   ticket_id:   cc.ticket_id.to_s,
                   user_id:     cc.user_id.to_s,
                   user_name:   cc.user&.fullname,
                   permissions: Array(cc.permissions),
                   message:     cc.message,
                   created_at:  cc.created_at,
                   updated_at:  cc.updated_at,
                 }
               end
               result
             else
               []
             end
  end
end
