class CreateShadowContactsForExistingAgents < ActiveRecord::Migration[7.0]
  def up
    AccountUser.find_each do |account_user|
      user = account_user.user
      account = account_user.account
      next if user.blank? || account.blank?
      next if Contact.exists?(account_id: account.id, shadow_user_id: user.id)

      Contact.create!(
        account_id: account.id,
        shadow_user_id: user.id,
        name: user.available_name || user.name,
        identifier: "agent:#{user.id}"
      )
    end
  end

  def down
    Contact.where.not(shadow_user_id: nil).destroy_all
  end
end
