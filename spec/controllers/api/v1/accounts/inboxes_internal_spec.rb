require 'rails_helper'

RSpec.describe 'Internal Inbox API', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes' do
    context 'when creating an internal inbox' do
      it 'creates the inbox as administrator' do
        post "/api/v1/accounts/#{account.id}/inboxes",
             headers: admin.create_new_auth_token,
             params: { name: 'Team Chat', channel: { type: 'internal' } },
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Team Chat')

        inbox = account.inboxes.find_by(name: 'Team Chat')
        expect(inbox).to be_present
        expect(inbox.channel_type).to eq('Channel::Internal')
        expect(inbox.internal?).to be true
      end

      it 'creates shadow contacts for all existing agents' do
        post "/api/v1/accounts/#{account.id}/inboxes",
             headers: admin.create_new_auth_token,
             params: { name: 'Team Chat', channel: { type: 'internal' } },
             as: :json

        expect(response).to have_http_status(:success)

        # Both admin and agent should have shadow contacts
        expect(Contact.find_by(account: account, shadow_user_id: admin.id)).to be_present
        expect(Contact.find_by(account: account, shadow_user_id: agent.id)).to be_present
      end

      it 'creates contact_inboxes for all shadow contacts' do
        post "/api/v1/accounts/#{account.id}/inboxes",
             headers: admin.create_new_auth_token,
             params: { name: 'Team Chat', channel: { type: 'internal' } },
             as: :json

        inbox = account.inboxes.find_by(name: 'Team Chat')
        shadow_contacts = Contact.where(account: account).where.not(shadow_user_id: nil)

        shadow_contacts.each do |contact|
          expect(ContactInbox.exists?(contact_id: contact.id, inbox_id: inbox.id)).to be true
        end
      end

      it 'adds all agents as inbox members' do
        post "/api/v1/accounts/#{account.id}/inboxes",
             headers: admin.create_new_auth_token,
             params: { name: 'Team Chat', channel: { type: 'internal' } },
             as: :json

        inbox = account.inboxes.find_by(name: 'Team Chat')
        member_ids = inbox.inbox_members.pluck(:user_id)

        expect(member_ids).to include(admin.id, agent.id)
      end

      it 'returns unauthorized for agents' do
        post "/api/v1/accounts/#{account.id}/inboxes",
             headers: agent.create_new_auth_token,
             params: { name: 'Team Chat', channel: { type: 'internal' } },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
