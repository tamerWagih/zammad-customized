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
        sql.push('group_id IN (?)')
        bind.push(user.group_ids_access(self.class::ACCESS_TYPE))

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
      end

      if user.permissions?('ticket.customer')
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

    def shared_ticket_ids(access)
      return [] unless user.permissions?('ticket.agent')

      group_ids = Array(user.group_ids_access(access)).compact
      return [] if group_ids.blank?

      Ticket::Share.active_current.where(group_id: group_ids).pluck(:ticket_id).uniq
    rescue StandardError => e
      Rails.logger.warn("Failed to resolve shared ticket ids for user #{user.id}: #{e.message}")
      []
    end

    def approval_ticket_ids
      return [] unless user.permissions?('ticket.agent')

      Ticket::Approval.where(approver_id: user.id).pluck(:ticket_id).uniq
    rescue StandardError => e
      Rails.logger.warn("Failed to resolve approval ticket ids for user #{user.id}: #{e.message}")
      []
    end
  end
end
