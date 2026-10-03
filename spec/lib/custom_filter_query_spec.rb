# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe CustomFilterQuery do
  describe '.clean_condition' do
    def selector_accepts?(condition)
      query, = Ticket.selector2sql(condition, current_user: create(:agent))
      query.present?
    end

    it 'drops a "specific" condition with an empty value (string keys, as stored in preferences)' do
      condition = {
        'ticket.state_id' => { 'operator' => 'is', 'value' => ['2'] },
        'ticket.owner_id' => { 'operator' => 'is', 'pre_condition' => 'specific', 'value' => [] },
      }
      expect(described_class.clean_condition(condition).keys).to eq(['ticket.state_id'])
    end

    it 'drops a "contains" condition with blank text' do
      condition = { 'ticket.number' => { 'operator' => 'contains', 'value' => '' } }
      expect(described_class.clean_condition(condition)).to eq({})
    end

    it 'keeps conditions whose pre_condition supplies the value' do
      condition = {
        'ticket.owner_id'    => { 'operator' => 'is', 'pre_condition' => 'current_user.id', 'value' => [] },
        'ticket.customer_id' => { 'operator' => 'is', 'pre_condition' => 'not_set', 'value' => [] },
      }
      expect(described_class.clean_condition(condition)).to eq(condition)
    end

    it 'keeps operators that need no value and normal conditions' do
      condition = {
        'ticket.title'      => { 'operator' => 'contains', 'value' => 'printer' },
        'ticket.state_id'   => { 'operator' => 'is', 'value' => ['1', '2'] },
        'ticket.updated_at' => { 'operator' => 'today' },
        'ticket.owner_id'   => { 'operator' => 'is set' },
      }
      expect(described_class.clean_condition(condition)).to eq(condition)
    end

    it 'does not change the stored filter' do
      condition = { 'ticket.owner_id' => { 'operator' => 'is', 'pre_condition' => 'specific', 'value' => [] } }
      described_class.clean_condition(condition)
      expect(condition).to have_key('ticket.owner_id')
    end

    it 'turns a filter Selector rejected into one it accepts' do
      condition = {
        'ticket.state_id' => { 'operator' => 'is', 'value' => [Ticket::State.find_by(name: 'open').id.to_s] },
        'ticket.owner_id' => { 'operator' => 'is', 'pre_condition' => 'specific', 'value' => [] },
      }
      expect(selector_accepts?(condition)).to be(false)
      expect(selector_accepts?(described_class.clean_condition(condition))).to be(true)
    end

    it 'returns an empty hash for a missing condition' do
      expect(described_class.clean_condition(nil)).to eq({})
    end
  end

  describe '.order_sql' do
    it 'qualifies the column with the tickets table' do
      expect(described_class.order_sql({ 'by' => 'created_at', 'direction' => 'ASC' })).to eq('tickets.created_at ASC')
    end

    it 'defaults to newest first' do
      expect(described_class.order_sql(nil)).to eq('tickets.created_at DESC')
    end

    it 'falls back to created_at for unknown or injected columns' do
      expect(described_class.order_sql({ 'by' => 'shared_with_me' })).to eq('tickets.created_at DESC')
      expect(described_class.order_sql({ 'by' => 'id; DROP TABLE tickets' })).to eq('tickets.created_at DESC')
    end

    it 'only allows ASC or DESC as direction' do
      expect(described_class.order_sql({ 'by' => 'number', 'direction' => 'asc' })).to eq('tickets.number ASC')
      expect(described_class.order_sql({ 'by' => 'number', 'direction' => 'DESC, (SELECT 1)' })).to eq('tickets.number DESC')
    end

    it 'sorts a filter that joins articles without an ambiguous-column error' do
      agent  = create(:agent, groups: [Group.first])
      ticket = create(:ticket, group: Group.first)
      create(:ticket_article, ticket: ticket, subject: 'printer jam')
      query, bind_params, tables = Ticket.selector2sql(
        { 'article.subject' => { 'operator' => 'contains', 'value' => 'printer' } },
        current_user: agent,
      )
      scope = TicketPolicy::OverviewScope.new(agent).resolve.where(query, *bind_params)
      scope = scope.joins(tables) if tables.present?

      expect { scope.reorder(Arel.sql('created_at DESC')).pluck(:id) }.to raise_error(ActiveRecord::StatementInvalid, %r{ambiguous})
      expect(scope.reorder(Arel.sql(described_class.order_sql({ 'by' => 'created_at' }))).pluck(:id)).to include(ticket.id)
    end
  end
end
