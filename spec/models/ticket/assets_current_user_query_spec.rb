# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Ticket#assets must not load the current user from the database for every ticket.
# Overview pushes and custom views build assets for up to 2000 tickets per request.
RSpec.describe Ticket, 'assets and the current user' do
  let(:agent)   { create(:agent, groups: [group]) }
  let(:group)   { create(:group) }
  let(:tickets) { create_list(:ticket, 10, group: group) }

  def build_assets
    tickets.each_with_object({}) { |t, data| described_class.find(t.id).assets(data) }
  end

  def query_count
    count = 0
    callback = ->(*, payload) { count += 1 unless payload[:name] == 'SCHEMA' || payload[:sql].include?('FROM "tickets"') }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
    count
  end

  before { UserInfo.current_user_id = agent.id }

  it 'keeps the asset output unchanged (no share_permissions key is added)' do
    data = build_assets
    ticket_assets = data[described_class.to_app_model].values
    expect(ticket_assets.size).to eq(10)
    expect(ticket_assets).to all(satisfy { |attrs| !attrs.key?('share_permissions') })
  end

  it 'does not query per ticket once attributes and users are cached' do
    build_assets
    expect(query_count { build_assets }).to eq(0)
  end
end
