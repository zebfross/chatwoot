class Internal::ShadowContactService
  def self.find_or_create_for(user:, account:)
    contact = account.contacts.find_by(shadow_user_id: user.id)
    return contact if contact

    account.contacts.create!(
      shadow_user_id: user.id,
      name: user.available_name || user.name,
      identifier: "agent:#{user.id}"
    )
  end

  def self.ensure_contact_inbox(contact:, inbox:)
    ContactInbox.find_by(contact_id: contact.id, inbox_id: inbox.id) ||
      ContactInbox.create!(contact_id: contact.id, inbox_id: inbox.id, source_id: SecureRandom.uuid)
  end
end
