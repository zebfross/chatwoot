class AddShadowUserIdToContacts < ActiveRecord::Migration[7.0]
  def change
    add_column :contacts, :shadow_user_id, :bigint
    add_index :contacts, [:account_id, :shadow_user_id],
              unique: true,
              where: 'shadow_user_id IS NOT NULL',
              name: 'index_contacts_on_account_and_shadow_user'
  end
end
