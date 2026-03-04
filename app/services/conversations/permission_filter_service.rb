class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    result = if user_role == 'administrator'
               conversations
             else
               accessible_conversations
             end

    filter_internal_conversations(result)
  end

  private

  def accessible_conversations
    conversations.where(inbox: user.inboxes.where(account_id: account.id))
  end

  # Internal conversations are private: agents (and admins) only see
  # conversations where they are assignee or their shadow contact is the contact.
  def filter_internal_conversations(convos)
    internal_inbox_ids = account.inboxes.where(channel_type: 'Channel::Internal').pluck(:id)
    return convos if internal_inbox_ids.empty?

    shadow_contact_id = account.contacts.where(shadow_user_id: user.id).pick(:id)

    convos.where(
      'conversations.inbox_id NOT IN (:internal_ids) OR conversations.assignee_id = :user_id OR conversations.contact_id = :contact_id',
      internal_ids: internal_inbox_ids,
      user_id: user.id,
      contact_id: shadow_contact_id
    )
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
