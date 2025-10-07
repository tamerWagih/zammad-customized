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
    Rails.logger.info "[TICKET_ASSETS_ALL] Ticket ##{ticket.id}: Building API response for user ##{user.id} (#{user.email})"
    
    approvals_data = approvals
    shares_data = shares
    
    Rails.logger.info "[TICKET_ASSETS_ALL] Ticket ##{ticket.id}: Approvals data size: #{approvals_data.size}"
    Rails.logger.info "[TICKET_ASSETS_ALL] Ticket ##{ticket.id}: Shares data size: #{shares_data.size}"
    
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
    }
    
    Rails.logger.info "[TICKET_ASSETS_ALL] Ticket ##{ticket.id}: API response built successfully"
    response_data
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
                     # Return all approvals for this ticket with user associations
                     result = ticket.approvals.includes(:approver, :requester).map do |approval|
                       {
                         id:           approval.id,
                         ticket_id:    approval.ticket_id,
                         approver_id:  approval.approver_id,
                         approver:     approval.approver&.attributes&.slice('id', 'firstname', 'lastname', 'email'),
                         requester_id: approval.requester_id,
                         requester:    approval.requester&.attributes&.slice('id', 'firstname', 'lastname', 'email'),
                         status:       approval.status,
                         message:      approval.message,
                         priority:     approval.priority,
                         created_at:   approval.created_at,
                         updated_at:   approval.updated_at,
                       }
                     end
                     Rails.logger.info "[APPROVAL_API] Ticket ##{ticket.id}: Returning #{result.size} approvals for user ##{user.id} (#{user.email})"
                     result
                   else
                     Rails.logger.info "[APPROVAL_API] Ticket ##{ticket.id}: No approvals returned (respond_to: #{ticket.respond_to?(:approvals)}, is_agent: #{user.permissions?('ticket.agent')})"
                     []
                   end
  end

  def shares
    @shares ||= if ticket.respond_to?(:shares) && user.permissions?('ticket.agent')
                  # Return all shares for this ticket with user and group associations
                  result = ticket.shares.includes(:shared_by, :group).map do |share|
                    {
                      id:           share.id,
                      ticket_id:    share.ticket_id,
                      group_id:     share.group_id,
                      group:        share.group&.attributes&.slice('id', 'name'),
                      shared_by_id: share.shared_by_id,
                      shared_by:    share.shared_by&.attributes&.slice('id', 'firstname', 'lastname', 'email'),
                      status:       share.status,
                      permissions:  share.permissions,
                      message:      share.message,
                      expires_at:   share.expires_at,
                      created_at:   share.created_at,
                      updated_at:   share.updated_at,
                    }
                  end
                  Rails.logger.info "[SHARE_API] Ticket ##{ticket.id}: Returning #{result.size} shares for user ##{user.id} (#{user.email})"
                  result
                else
                  Rails.logger.info "[SHARE_API] Ticket ##{ticket.id}: No shares returned (respond_to: #{ticket.respond_to?(:shares)}, is_agent: #{user.permissions?('ticket.agent')})"
                  []
                end
  end
end
