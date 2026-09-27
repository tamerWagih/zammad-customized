# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Shared/approval/CC ticket IDs must reach Elasticsearch as a `terms` filter.
# As a query_string OR-list every ID counted against the 4096-clause limit and
# searches such as "Ticket#<number>" failed with "too many clauses".
RSpec.describe Ticket::Search, 'shared ticket access in search' do
  let(:own_group)   { create(:group) }
  let(:other_group) { create(:group) }
  let(:agent)       { create(:agent, groups: [own_group]) }
  let(:ticket)      { create(:ticket, group: other_group) }

  before do
    Ticket::Share.create!(ticket: ticket, group: own_group, shared_by: create(:agent), status: 'active', permissions: ['comment'])
  end

  describe '.search_query_extension' do
    subject(:extension) { Ticket.search_query_extension(current_user: agent, scope: TicketPolicy::ReadScope) }

    let(:should_clauses) { extension[:bool][:must].first[:bool][:should] }

    it 'passes shared ticket IDs as a terms filter' do
      expect(should_clauses).to include({ 'terms' => { 'id' => [ticket.id] } })
    end

    it 'never builds an id query_string OR-list' do
      expect(should_clauses.map { |c| c.dig('query_string', 'default_field') }).not_to include('id')
    end

    context 'with more shared tickets than the 4096 clause limit' do
      let(:many_ids) { (1..5000).to_a }

      before { allow(Ticket).to receive(:get_shared_ticket_ids).and_return(many_ids) }

      it 'keeps all IDs in a single terms filter' do
        expect(should_clauses).to include({ 'terms' => { 'id' => many_ids } })
      end
    end
  end

  describe 'searching a shared ticket by its complete ticket hook', searchindex: true do
    before { searchindex_model_reload([Ticket]) }

    it 'finds the ticket' do
      expect(Ticket.search(current_user: agent, query: "#{Setting.get('ticket_hook')}#{ticket.number}")).to eq([ticket])
    end
  end
end
