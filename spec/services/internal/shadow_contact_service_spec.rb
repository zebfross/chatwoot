require 'rails_helper'

RSpec.describe Internal::ShadowContactService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before do
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
  end

  describe '.find_or_create_for' do
    it 'creates a shadow contact for the user' do
      contact = described_class.find_or_create_for(user: user, account: account)

      expect(contact).to be_persisted
      expect(contact.shadow_user_id).to eq(user.id)
      expect(contact.account_id).to eq(account.id)
      expect(contact.identifier).to eq("agent:#{user.id}")
      expect(contact.name).to eq(user.available_name)
    end

    it 'returns existing shadow contact if one exists' do
      first_contact = described_class.find_or_create_for(user: user, account: account)
      second_contact = described_class.find_or_create_for(user: user, account: account)

      expect(first_contact.id).to eq(second_contact.id)
    end

    it 'creates separate shadow contacts per account' do
      other_account = create(:account)
      create(:account_user, user: user, account: other_account)

      contact_1 = described_class.find_or_create_for(user: user, account: account)
      contact_2 = described_class.find_or_create_for(user: user, account: other_account)

      expect(contact_1.id).not_to eq(contact_2.id)
      expect(contact_1.account_id).to eq(account.id)
      expect(contact_2.account_id).to eq(other_account.id)
    end
  end

  describe '.ensure_contact_inbox' do
    it 'creates a contact inbox linking shadow contact to inbox' do
      channel = create(:channel_internal, account: account)
      inbox = channel.inbox
      contact = described_class.find_or_create_for(user: user, account: account)

      contact_inbox = described_class.ensure_contact_inbox(contact: contact, inbox: inbox)

      expect(contact_inbox).to be_persisted
      expect(contact_inbox.contact_id).to eq(contact.id)
      expect(contact_inbox.inbox_id).to eq(inbox.id)
    end

    it 'does not create duplicate contact inboxes' do
      channel = create(:channel_internal, account: account)
      inbox = channel.inbox
      contact = described_class.find_or_create_for(user: user, account: account)

      described_class.ensure_contact_inbox(contact: contact, inbox: inbox)
      # Second call should find existing, not raise
      expect {
        described_class.ensure_contact_inbox(contact: contact, inbox: inbox)
      }.not_to change(ContactInbox, :count)
    end
  end
end
