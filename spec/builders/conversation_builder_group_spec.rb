require 'rails_helper'

RSpec.describe ConversationBuilder do
  let(:account) { create(:account) }
  let(:internal_channel) { create(:channel_internal, account: account) }
  let(:inbox) { create(:inbox, account: account, channel: internal_channel) }
  let(:user1) { create(:user, account: account) }
  let(:user2) { create(:user, account: account) }
  let(:user3) { create(:user, account: account) }

  describe 'group conversation creation' do
    let(:params) do
      ActionController::Parameters.new(
        account_id: account.id,
        inbox_id: inbox.id,
        conversation_type: 'group_conversation',
        assignee_id: user1.id,
        participant_user_ids: [user1.id, user2.id, user3.id]
      )
    end

    it 'creates a group conversation with participants' do
      conversation = described_class.new(params: params).perform

      expect(conversation).to be_persisted
      expect(conversation.group_conversation?).to be true
      expect(conversation.contact_id).to be_nil
      expect(conversation.participants.count).to eq(3)
      expect(conversation.participants).to include(user1, user2, user3)
    end

    it 'sets the correct inbox' do
      conversation = described_class.new(params: params).perform

      expect(conversation.inbox).to eq(inbox)
    end

    it 'sets the assignee' do
      conversation = described_class.new(params: params).perform

      expect(conversation.assignee).to eq(user1)
    end
  end
end
