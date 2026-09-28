# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Behavior lock for the custom access features (shares, approvals, CCs, custom views, search).
# An agent of another group must see exactly the tickets these features grant, nothing more.
RSpec.describe 'Custom access features', type: :request do
  let(:group_a)   { create(:group) }
  let(:group_b)   { create(:group) }
  let(:owner)     { create(:agent, groups: [group_a]) }
  let(:agent_b)   { create(:agent, groups: [group_b]) }
  let(:open_state_ids) { Ticket::State.by_category(:open).pluck(:id).map(&:to_s) }

  # records below log activity streams, which need an acting user
  before { UserInfo.current_user_id = 1 }

  let!(:t_shared)   { create(:ticket, group: group_a, title: 'shared ticket') }
  let!(:t_approval) { create(:ticket, group: group_a, title: 'approval ticket') }
  let!(:t_cc)       { create(:ticket, group: group_a, title: 'cc ticket') }
  let!(:t_none)     { create(:ticket, group: group_a, title: 'unrelated ticket') }

  let!(:share)    { Ticket::Share.create!(ticket: t_shared, group: group_b, shared_by: owner, status: 'active', permissions: ['comment']) }
  let!(:approval) { Ticket::Approval.create!(ticket: t_approval, approver: agent_b, requester: owner) }
  let!(:cc)       { Ticket::Cc.create!(ticket: t_cc, user: agent_b) }

  def show(ticket)
    authenticated_as(agent_b)
    get "/api/v1/tickets/#{ticket.id}", as: :json
    response
  end

  describe 'shares' do
    it 'grants access to a ticket shared with the agent group' do
      expect(show(t_shared)).to have_http_status(:ok)
    end

    it 'denies access to an unrelated ticket of another group' do
      expect(show(t_none)).to have_http_status(:forbidden)
    end

    it 'removes access when the share is revoked' do
      share.update!(status: 'revoked')
      expect(show(t_shared)).to have_http_status(:forbidden)
    end
  end

  describe 'approvals' do
    it 'grants access to the approver' do
      expect(show(t_approval)).to have_http_status(:ok)
    end

    it 'keeps access after the approval is approved' do
      approval.update!(status: 'approved')
      expect(show(t_approval)).to have_http_status(:ok)
    end
  end

  describe 'CCs' do
    it 'grants access to the CC user' do
      expect(show(t_cc)).to have_http_status(:ok)
    end

    it 'returns cc_user_ids in the ticket assets the UI loads' do
      authenticated_as(agent_b)
      get "/api/v1/tickets/#{t_cc.id}?all=true", as: :json
      expect(json_response.dig('assets', 'Ticket', t_cc.id.to_s, 'cc_user_ids')).to eq([agent_b.id])
    end

    it 'removes access when the CC is removed' do
      cc.destroy!
      expect(show(t_cc)).to have_http_status(:forbidden)
    end
  end

  describe 'custom views' do
    let(:filter) do
      { 'id' => SecureRandom.uuid, 'name' => 'Open', 'link' => 'open_custom', 'active' => true, 'prio' => 2000, 'is_custom' => true,
        'condition' => { 'ticket.state_id' => { 'operator' => 'is', 'value' => open_state_ids } },
        'order' => { 'by' => 'created_at', 'direction' => 'DESC' } }
    end

    before do
      agent_b.preferences[:custom_filters] = [filter]
      agent_b.save!
      authenticated_as(agent_b)
    end

    it 'counts only the tickets granted by share, approval and CC' do
      get '/api/v1/ticket_overviews', as: :json
      meta = json_response.find { |o| o['link'] == 'open_custom' }
      expect(meta['count']).to eq(3)
    end

    it 'lists only the tickets granted by share, approval and CC' do
      get '/api/v1/ticket_overviews?view=open_custom', as: :json
      ids = json_response.dig('index', 'tickets').pluck('id')
      expect(ids).to contain_exactly(t_shared.id, t_approval.id, t_cc.id)
    end
  end

  describe 'search', searchindex: true do
    before do
      searchindex_model_reload([Ticket])
      authenticated_as(agent_b)
    end

    def found(ticket)
      get "/api/v1/tickets/search?query=#{ticket.number}&limit=10", as: :json
      Array(json_response).pluck('id')
    end

    it 'finds tickets granted by share, approval and CC' do
      expect([t_shared, t_approval, t_cc].map { |t| found(t) }).to eq([[t_shared.id], [t_approval.id], [t_cc.id]])
    end

    it 'does not find an unrelated ticket of another group' do
      expect(found(t_none)).to eq([])
    end
  end
end
