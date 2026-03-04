require 'rails_helper'

RSpec.describe 'Internal Contacts API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
  end

  describe 'GET /api/v1/accounts/{account.id}/internal_contacts' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/internal_contacts"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      it 'returns empty array when no internal inbox exists' do
        get "/api/v1/accounts/#{account.id}/internal_contacts",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq([])
      end

      it 'returns agents with shadow contact IDs when internal inbox exists' do
        channel = create(:channel_internal, account: account)

        # Create shadow contacts for existing agents
        shadow_admin = Internal::ShadowContactService.find_or_create_for(user: admin, account: account)
        shadow_agent = Internal::ShadowContactService.find_or_create_for(user: agent, account: account)

        get "/api/v1/accounts/#{account.id}/internal_contacts",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        data = JSON.parse(response.body)
        expect(data.length).to eq(2)

        ids = data.map { |d| d['id'] }
        expect(ids).to include(admin.id, agent.id)

        shadow_ids = data.map { |d| d['shadow_contact_id'] }
        expect(shadow_ids).to include(shadow_admin.id, shadow_agent.id)
      end
    end
  end
end
