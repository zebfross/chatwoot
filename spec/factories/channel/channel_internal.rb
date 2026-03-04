FactoryBot.define do
  factory :channel_internal, class: 'Channel::Internal' do
    account
    after(:create) do |channel_internal|
      create(:inbox, channel: channel_internal, account: channel_internal.account, name: 'Internal')
    end
  end
end
