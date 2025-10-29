# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Ticket::Search
  extend ActiveSupport::Concern

  include CanSearch

  included do
    scope :search_sql_query_extension, lambda { |params|
      query = params[:query]&.delete('*')
      return if query.blank?

      fields = %w[title number]
      fields << Ticket::Article.arel_table[:body]
      fields << Ticket::Article.arel_table[:from]
      fields << Ticket::Article.arel_table[:to]
      fields << Ticket::Article.arel_table[:subject]

      where_or_cis(fields, "%#{SqlHelper.quote_like(query)}%")
        .joins(:articles)
    }
  end

  # methods defined here are going to extend the class, not the instance of it
  class_methods do

=begin

search tickets preferences

  result = Ticket.search_preferences(user_model)

returns if user has permissions to search

  result = {
    prio: 3000,
    direct_search_index: false
  }

returns if user has no permissions to search

  result = false

=end

    def search_preferences(current_user)
      return false if !current_user.permissions?(['ticket.agent', 'ticket.customer'])

      {
        prio:                3000,
        direct_search_index: false,
      }
    end

    def search_params_pre(params)
      params[:scope] ||= TicketPolicy::ReadScope
    end

    def search_query_extension(params)
      query_or = []
      if params[:current_user].permissions?('ticket.agent')
        group_ids = params[:current_user].group_ids_access(params[:scope].const_get(:ACCESS_TYPE))
        if group_ids.present?
          access_condition = {
            'query_string' => { 'default_field' => 'group_id', 'query' => "\"#{group_ids.join('" OR "')}\"" }
          }
          query_or.push(access_condition)
        end

        # Include shared tickets
        shared_ticket_ids = get_shared_ticket_ids(params)
        if shared_ticket_ids.present?
          access_condition = {
            'query_string' => { 'default_field' => 'id', 'query' => "\"#{shared_ticket_ids.join('" OR "')}\"" }
          }
          query_or.push(access_condition)
        end

        # Include approval tickets
        approval_ticket_ids = get_approval_ticket_ids(params)
        if approval_ticket_ids.present?
          access_condition = {
            'query_string' => { 'default_field' => 'id', 'query' => "\"#{approval_ticket_ids.join('" OR "')}\"" }
          }
          query_or.push(access_condition)
        end
      end
      if params[:current_user].permissions?('ticket.customer')
        organizations_query = params[:current_user].all_organizations.where(shared: true).map { |row| "organization_id:#{row.id}" }.join(' OR ')
        access_condition    = if organizations_query.present?
                                {
                                  'query_string' => { 'query' => "customer_id:#{params[:current_user].id} OR #{organizations_query}" }
                                }
                              else
                                {
                                  'query_string' => { 'default_field' => 'customer_id', 'query' => params[:current_user].id }
                                }
                              end
        query_or.push(access_condition)
      end

      if query_or.blank?
        return {
          bool: {
            must: [
              {
                'query_string' => { 'query' => 'id:0' }
              },
            ],
          }
        }
      end

      {
        bool: {
          must: [
            {
              bool: {
                should: query_or,
              },
            },
          ],
        }
      }
    end

    private

    def get_shared_ticket_ids(params)
      return [] unless params[:current_user].permissions?('ticket.agent')

      group_ids = Array(params[:current_user].group_ids_access(params[:scope].const_get(:ACCESS_TYPE))).compact
      return [] if group_ids.blank?

      Ticket::Share.active_current.where(group_id: group_ids).pluck(:ticket_id).uniq
    rescue StandardError => e
      Rails.logger.warn("Failed to resolve shared ticket ids for search: #{e.message}")
      []
    end

    def get_approval_ticket_ids(params)
      return [] unless params[:current_user].permissions?('ticket.agent')

      Ticket::Approval.where(approver_id: params[:current_user].id).pluck(:ticket_id).uniq
    rescue StandardError => e
      Rails.logger.warn("Failed to resolve approval ticket ids for search: #{e.message}")
      []
    end
  end
end
