class ConversationBuilder
  pattr_initialize [:params!, :contact_inbox]

  def perform
    if group_conversation?
      create_group_conversation
    else
      look_up_exising_conversation || create_new_conversation
    end
  end

  private

  def group_conversation?
    params[:conversation_type] == 'group_conversation'
  end

  def look_up_exising_conversation
    return unless @contact_inbox.inbox.lock_to_single_conversation?

    @contact_inbox.conversations.last
  end

  def create_new_conversation
    ::Conversation.create!(conversation_params)
  end

  def create_group_conversation
    inbox = Account.find(params[:account_id]).inboxes.find(params[:inbox_id])
    conversation = ::Conversation.create!(
      account_id: params[:account_id],
      inbox_id: inbox.id,
      conversation_type: :group_conversation,
      status: :open,
      assignee_id: params[:assignee_id]
    )
    participant_ids = params[:participant_user_ids] || []
    participant_ids.each do |user_id|
      conversation.conversation_participants.create!(user_id: user_id)
    end
    conversation
  end

  def conversation_params
    additional_attributes = params[:additional_attributes]&.permit! || {}
    custom_attributes = params[:custom_attributes]&.permit! || {}
    status = params[:status].present? ? { status: params[:status] } : {}

    # TODO: temporary fallback for the old bot status in conversation, we will remove after couple of releases
    # commenting this out to see if there are any errors, if not we can remove this in subsequent releases
    # status = { status: 'pending' } if status[:status] == 'bot'
    {
      account_id: @contact_inbox.inbox.account_id,
      inbox_id: @contact_inbox.inbox_id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: additional_attributes,
      custom_attributes: custom_attributes,
      snoozed_until: params[:snoozed_until],
      assignee_id: params[:assignee_id],
      team_id: params[:team_id]
    }.merge(status)
  end
end
