# == Schema Information
#
# Table name: channel_internal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#
# Indexes
#
#  index_channel_internal_on_account_id  (account_id)
#

class Channel::Internal < ApplicationRecord
  include Channelable

  self.table_name = 'channel_internal'
  EDITABLE_ATTRS = [].freeze

  def name
    'Internal'
  end
end
