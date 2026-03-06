require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let(:internal_channel) { create(:channel_internal, account: account) }
  let(:inbox) { create(:inbox, account: account, channel: internal_channel) }
  let(:user1) { create(:user, account: account) }
  let(:user2) { create(:user, account: account) }
  let(:user3) { create(:user, account: account) }

  describe 'group conversation filtering' do
    let!(:group_conversation) do
      conv = Conversation.create!(
        account: account,
        inbox: inbox,
        conversation_type: :group,
        assignee: user1
      )
      conv.conversation_participants.create!(user: user1)
      conv.conversation_participants.create!(user: user2)
      conv
    end

    it 'shows group conversation to participants' do
      result = described_class.new(
        account.conversations, user1, account
      ).perform

      expect(result).to include(group_conversation)
    end

    it 'shows group conversation to other participant' do
      result = described_class.new(
        account.conversations, user2, account
      ).perform

      expect(result).to include(group_conversation)
    end

    it 'hides group conversation from non-participants' do
      result = described_class.new(
        account.conversations, user3, account
      ).perform

      expect(result).not_to include(group_conversation)
    end
  end
end
