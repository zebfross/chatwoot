require 'rails_helper'

RSpec.describe 'Group Conversations' do
  let(:account) { create(:account) }
  let(:internal_channel) { create(:channel_internal, account: account) }
  let(:inbox) { create(:inbox, account: account, channel: internal_channel) }
  let(:user1) { create(:user, account: account) }
  let(:user2) { create(:user, account: account) }
  let(:user3) { create(:user, account: account) }

  describe 'creating a group conversation' do
    it 'allows creating a conversation without contact_id when type is group' do
      conversation = Conversation.create!(
        account: account,
        inbox: inbox,
        conversation_type: :group,
        assignee: user1
      )
      expect(conversation).to be_persisted
      expect(conversation.group?).to be true
      expect(conversation.contact_id).to be_nil
    end

    it 'still requires contact_id for direct conversations' do
      conversation = Conversation.new(
        account: account,
        inbox: inbox,
        conversation_type: :direct
      )
      expect(conversation).not_to be_valid
      expect(conversation.errors[:contact_id]).to be_present
    end

    it 'can have multiple participants' do
      conversation = Conversation.create!(
        account: account,
        inbox: inbox,
        conversation_type: :group,
        assignee: user1
      )
      conversation.conversation_participants.create!(user: user1)
      conversation.conversation_participants.create!(user: user2)
      conversation.conversation_participants.create!(user: user3)

      expect(conversation.participants.count).to eq(3)
      expect(conversation.participants).to include(user1, user2, user3)
    end
  end

  describe 'conversation_type enum' do
    it 'defaults to direct' do
      contact = create(:contact, account: account)
      contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
      conversation = Conversation.create!(
        account: account,
        inbox: inbox,
        contact: contact,
        contact_inbox: contact_inbox
      )
      expect(conversation.direct?).to be true
    end

    it 'can be set to group' do
      conversation = Conversation.create!(
        account: account,
        inbox: inbox,
        conversation_type: :group,
        assignee: user1
      )
      expect(conversation.group?).to be true
      expect(conversation.direct?).to be false
    end
  end
end
