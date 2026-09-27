# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Shared tickets must be visible to members of the group they are shared with,
# via a subquery rather than a literal ID list (performance, see base_scope.rb).
RSpec.describe TicketPolicy::ReadScope, 'ticket shares' do
  subject(:resolved) { described_class.new(user).resolve }

  let(:own_group)     { create(:group) }
  let(:other_group)   { create(:group) }
  let(:third_group)   { create(:group) }
  let(:user)          { create(:agent, groups: [own_group]) }
  let(:ticket)        { create(:ticket, group: other_group) }

  def share(ticket, group, status: 'active')
    Ticket::Share.create!(ticket: ticket, group: group, shared_by: create(:agent), status: status, permissions: ['comment'])
  end

  it 'includes a ticket shared with the user group' do
    share(ticket, own_group)
    expect(resolved).to include(ticket)
  end

  it 'excludes a ticket shared with another group' do
    share(ticket, third_group)
    expect(resolved).not_to include(ticket)
  end

  it 'excludes a ticket whose share was revoked' do
    share(ticket, own_group, status: 'revoked')
    expect(resolved).not_to include(ticket)
  end

  it 'excludes a ticket from another group with no share' do
    expect(resolved).not_to include(ticket)
  end

  it 'queries shares with a subquery instead of embedding ticket IDs' do
    share(ticket, own_group)
    expect(resolved.to_sql).to include('SELECT "ticket_shares"."ticket_id" FROM "ticket_shares"')
  end
end
