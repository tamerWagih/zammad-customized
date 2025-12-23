# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Abstract base class for various "types" of ticket access.
#
# Do NOT instantiate directly; instead,
# choose the appropriate subclass from below
# (see commit message for details).
class TicketPolicy < ApplicationPolicy
  class BaseScope < ApplicationPolicy::Scope

    # overwrite PunditPolicy#initialize to make `context` optional and use Ticket as default
    def initialize(user, context = Ticket)
      super
    end

    def resolve # rubocop:disable Metrics/AbcSize
      raise NoMethodError, <<~ERR.chomp if instance_of?(TicketPolicy::BaseScope)
        specify an access type using a subclass of TicketPolicy::BaseScope
      ERR

      sql  = []
      bind = []

      if user.permissions?('ticket.agent')
        # Include tickets from groups user has access to
        group_ids = user.group_ids_access(self.class::ACCESS_TYPE)
        if group_ids.present?
          sql.push('group_id IN (?)')
          bind.push(group_ids)
        end

        # Include shared tickets
        shared_ids = shared_ticket_ids(self.class::ACCESS_TYPE)
        if shared_ids.present?
          sql.push('tickets.id IN (?)')
          bind.push(shared_ids)
        end

        # Include approval tickets (approvers can see tickets they need to approve)
        approval_ids = approval_ticket_ids
        if approval_ids.present?
          sql.push('tickets.id IN (?)')
          bind.push(approval_ids)
        end

        # Include CC tickets (CC'd users can see tickets they are CC'd on)
        cc_ids = cc_ticket_ids
        if cc_ids.present?
          sql.push('tickets.id IN (?)')
          bind.push(cc_ids)
        end

        # Include tickets created by user (for creator_access? to work)
        sql.push('tickets.created_by_id = ?')
        bind.push(user.id)
      end

      if user.permissions?('ticket.customer')
        # Include CC tickets for customers too (CC'd customers can see tickets)
        cc_ids = cc_ticket_ids
        if cc_ids.present?
          sql.push('tickets.id IN (?)')
          bind.push(cc_ids)
        end

        sql.push('tickets.customer_id = ?')
        bind.push(user.id)

        if user.all_organization_ids.present?
          Organization.where(id: user.all_organization_ids).select(&:shared).each do |organization|
            sql.push('tickets.organization_id = ?')
            bind.push(organization.id)
          end
        end
      end

      # The report permission can access all tickets.
      if sql.empty? && !user.permissions?('report')
        sql.push '0 = 1' # Forbid unlimited access for all other permissions.
      end

      scope.where sql.join(' OR '), *bind
    end

    # #resolve is UNDEFINED BEHAVIOR for the abstract base class (but not its subclasses)
    def respond_to?(*args)
      return false if args.first.to_s == 'resolve' && instance_of?(TicketPolicy::BaseScope)

      super
    end

    private

    # Cache shared ticket IDs per request using Zammad's native Auth::RequestCache pattern
    # This prevents repeated DB queries when multiple scopes are resolved in one request
    def shared_ticket_ids(access)
      return [] unless user.permissions?('ticket.agent')

      Auth::RequestCache.fetch_value("TicketPolicy/BaseScope/shared_ticket_ids/#{user.id}") do
        # Get ALL groups the user belongs to (any access level)
        # Don't filter by access - if user is in a group that's shared with, they should see the ticket
        # This matches approval behavior where approvers see tickets regardless of group access
        group_ids = user_group_ids_cached
        if group_ids.blank?
          []
        else
          Ticket::Share.active_current.where(group_id: group_ids).pluck(:ticket_id).uniq
        end
      end
    rescue StandardError => e
      Rails.logger.warn("Failed to resolve shared ticket ids for user #{user.id}: #{e.message}")
      []
    end

    # Cache approval ticket IDs per request
    def approval_ticket_ids
      return [] unless user.permissions?('ticket.agent')

      Auth::RequestCache.fetch_value("TicketPolicy/BaseScope/approval_ticket_ids/#{user.id}") do
        Ticket::Approval.where(approver_id: user.id).pluck(:ticket_id).uniq
      end
    rescue StandardError => e
      Rails.logger.warn("Failed to resolve approval ticket ids for user #{user.id}: #{e.message}")
      []
    end

    # Cache CC ticket IDs per request
    def cc_ticket_ids
      return [] unless user

      Auth::RequestCache.fetch_value("TicketPolicy/BaseScope/cc_ticket_ids/#{user.id}") do
        # Include tickets where user is CC'd (both agents and customers)
        Ticket::Cc.where(user_id: user.id).pluck(:ticket_id).uniq
      end
    rescue StandardError => e
      Rails.logger.warn("Failed to resolve CC ticket ids for user #{user.id}: #{e.message}")
      []
    end

    # Cache user group IDs per request (used by shared_ticket_ids)
    def user_group_ids_cached
      Auth::RequestCache.fetch_value("TicketPolicy/BaseScope/user_group_ids/#{user.id}") do
        user.groups.pluck(:id)
      end
    end
  end
end
