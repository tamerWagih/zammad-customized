# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Ticket::Share, Ticket::Approval and Ticket::Cc must index like any other model.
# Their former search_index_attribute_lookup overrides had a wrong signature
# (ArgumentError on every index update, aborting a full index rebuild) and sent
# values that clash with the index mappings.
RSpec.describe 'Custom ticket models search indexing', searchindex: true do
  let(:ticket) { create(:ticket) }
  let(:agent)  { create(:agent) }

  shared_examples 'indexable' do
    it 'sends the record to the search index' do
      expect { record.search_index_update_backend }.not_to raise_error
    end
  end

  context 'with Ticket::Share' do
    let(:record) { Ticket::Share.create!(ticket: ticket, group: create(:group), shared_by: agent, status: 'active', permissions: ['comment']) }

    it_behaves_like 'indexable'
  end

  context 'with Ticket::Approval' do
    let(:record) { Ticket::Approval.create!(ticket: ticket, approver: agent, requester: create(:agent)) }

    it_behaves_like 'indexable'
  end

  context 'with Ticket::Cc' do
    let(:record) { Ticket::Cc.create!(ticket: ticket, user: agent) }

    it_behaves_like 'indexable'
  end
end
