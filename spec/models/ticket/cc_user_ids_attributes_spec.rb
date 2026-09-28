# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# cc_user_ids must be part of the cached ticket attributes, so building ticket assets
# (overview pushes: up to 2000 tickets per overview) does not query ticket_ccs per ticket.
RSpec.describe Ticket, 'cc_user_ids in cached attributes' do
  let(:ticket)  { create(:ticket) }
  let(:cc_user) { create(:agent, groups: [ticket.group]) }

  def ticket_ccs_queries
    count = 0
    callback = ->(*, payload) { count += 1 if payload[:sql].include?('ticket_ccs') }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
    count
  end

  before { Ticket::Cc.create!(ticket: ticket, user: cc_user) }

  it 'includes the CC user ids' do
    expect(described_class.find(ticket.id).attributes_with_association_ids['cc_user_ids']).to eq([cc_user.id])
  end

  it 'does not query ticket_ccs when the attributes come from the cache' do
    described_class.find(ticket.id).attributes_with_association_ids
    fresh = described_class.find(ticket.id)
    expect(ticket_ccs_queries { fresh.attributes_with_association_ids }).to eq(0)
  end

  it 'refreshes the CC user ids when a CC is added' do
    described_class.find(ticket.id).attributes_with_association_ids
    other = create(:agent, groups: [ticket.group])
    Ticket::Cc.create!(ticket: ticket, user: other)
    expect(described_class.find(ticket.id).attributes_with_association_ids['cc_user_ids']).to contain_exactly(cc_user.id, other.id)
  end

  it 'refreshes the CC user ids when a CC is removed' do
    described_class.find(ticket.id).attributes_with_association_ids
    Ticket::Cc.find_by(ticket: ticket, user: cc_user).destroy!
    expect(described_class.find(ticket.id).attributes_with_association_ids['cc_user_ids']).to eq([])
  end
end
