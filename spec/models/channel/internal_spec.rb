require 'rails_helper'

RSpec.describe Channel::Internal do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:account_id) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_one(:inbox).dependent(:destroy_async) }
  end

  describe '#name' do
    it 'returns Internal' do
      channel = build(:channel_internal)
      expect(channel.name).to eq('Internal')
    end
  end
end
