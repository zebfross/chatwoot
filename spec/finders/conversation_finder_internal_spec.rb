require 'rails_helper'

describe ConversationFinder, 'internal inbox filtering' do
  let!(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:regular_inbox) { create(:inbox, account: account, enable_auto_assignment: false) }

  before do
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
    create(:inbox_member, user: agent, inbox: regular_inbox)

    # Create regular conversations
    create(:conversation, account: account, inbox: regular_inbox, assignee: agent)
    create(:conversation, account: account, inbox: regular_inbox)

    Current.account = account
  end

  describe '#perform' do
    context 'when no inbox_id is specified' do
      it 'excludes internal inbox conversations from results' do
        channel = create(:channel_internal, account: account)
        internal_inbox = channel.inbox
        create(:inbox_member, user: agent, inbox: internal_inbox)

        shadow_contact = create(:contact, account: account, shadow_user_id: agent.id, identifier: "agent:#{agent.id}")
        contact_inbox = create(:contact_inbox, inbox: internal_inbox, contact: shadow_contact)
        create(:conversation, account: account, inbox: internal_inbox, contact: shadow_contact, contact_inbox: contact_inbox)

        params = { assignee_type: 'all' }
        result = described_class.new(admin, params).perform

        inbox_ids = result[:conversations].map(&:inbox_id).uniq
        expect(inbox_ids).not_to include(internal_inbox.id)
        expect(result[:conversations].length).to eq(2)
      end
    end

    context 'when inbox_id is specified for internal inbox' do
      it 'returns internal conversations when explicitly filtering by internal inbox' do
        channel = create(:channel_internal, account: account)
        internal_inbox = channel.inbox
        create(:inbox_member, user: admin, inbox: internal_inbox)

        shadow_contact = create(:contact, account: account, shadow_user_id: agent.id, identifier: "agent:#{agent.id}")
        contact_inbox = create(:contact_inbox, inbox: internal_inbox, contact: shadow_contact)
        internal_convo = create(:conversation, account: account, inbox: internal_inbox, contact: shadow_contact, contact_inbox: contact_inbox)

        params = { inbox_id: internal_inbox.id }
        result = described_class.new(admin, params).perform

        expect(result[:conversations].map(&:id)).to include(internal_convo.id)
      end
    end

    context 'when no internal inbox exists' do
      it 'returns all conversations normally' do
        params = { assignee_type: 'all' }
        result = described_class.new(admin, params).perform

        expect(result[:conversations].length).to eq(2)
      end
    end
  end
end
