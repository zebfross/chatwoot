require 'rails_helper'

RSpec.describe 'Internal Messaging' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before do
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
  end

  describe 'Inbox#internal?' do
    it 'returns true for internal channel type' do
      channel = create(:channel_internal, account: account)
      expect(channel.inbox.internal?).to be true
    end

    it 'returns false for other channel types' do
      inbox = create(:inbox, account: account)
      expect(inbox.internal?).to be false
    end
  end

  describe 'Contact shadow scopes' do
    let!(:regular_contact) { create(:contact, account: account) }
    let!(:shadow_contact) do
      create(:contact, account: account, shadow_user_id: admin.id, identifier: "agent:#{admin.id}")
    end

    it 'shadow_contacts returns only shadow contacts' do
      expect(account.contacts.shadow_contacts).to include(shadow_contact)
      expect(account.contacts.shadow_contacts).not_to include(regular_contact)
    end

    it 'non_shadow returns only regular contacts' do
      expect(account.contacts.non_shadow).to include(regular_contact)
      expect(account.contacts.non_shadow).not_to include(shadow_contact)
    end
  end

  describe 'Contact#shadow_user' do
    it 'returns the associated user' do
      contact = create(:contact, account: account, shadow_user_id: admin.id, identifier: "agent:#{admin.id}")
      expect(contact.shadow_user).to eq(admin)
    end
  end

  describe 'ConversationParticipant validation for internal inbox' do
    it 'allows any account agent as participant for internal inbox conversations' do
      channel = create(:channel_internal, account: account)
      inbox = channel.inbox
      agent = create(:user, account: account, role: :agent)

      shadow_contact = create(:contact, account: account, shadow_user_id: agent.id, identifier: "agent:#{agent.id}")
      contact_inbox = create(:contact_inbox, inbox: inbox, contact: shadow_contact)
      conversation = create(:conversation, account: account, inbox: inbox, contact: shadow_contact, contact_inbox: contact_inbox)

      another_agent = create(:user, account: account, role: :agent)
      participant = build(:conversation_participant, conversation: conversation, user: another_agent)

      expect(participant).to be_valid
    end
  end

  describe 'AccountUser#create_shadow_contact callback' do
    it 'creates shadow contact when internal inbox exists' do
      channel = create(:channel_internal, account: account)

      new_user = create(:user)
      # Creating the account_user triggers the callback
      expect {
        create(:account_user, user: new_user, account: account)
      }.to change { account.contacts.where.not(shadow_user_id: nil).count }.by(1)

      shadow = account.contacts.find_by(shadow_user_id: new_user.id)
      expect(shadow).to be_present
      expect(shadow.identifier).to eq("agent:#{new_user.id}")
    end

    it 'does not create shadow contact when no internal inbox exists' do
      new_user = create(:user)

      expect {
        create(:account_user, user: new_user, account: account)
      }.not_to change { account.contacts.where.not(shadow_user_id: nil).count }
    end

    it 'creates contact_inbox for each internal inbox' do
      channel = create(:channel_internal, account: account)
      inbox = channel.inbox

      new_user = create(:user)
      create(:account_user, user: new_user, account: account)

      shadow = account.contacts.find_by(shadow_user_id: new_user.id)
      expect(ContactInbox.exists?(contact_id: shadow.id, inbox_id: inbox.id)).to be true
    end
  end

  describe 'Account#internal_channels' do
    it 'returns internal channels' do
      channel = create(:channel_internal, account: account)
      expect(account.internal_channels).to include(channel)
    end
  end
end
