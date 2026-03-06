class Imap::ImapMailbox
  include MailboxHelper
  include IncomingEmailValidityHelper
  attr_accessor :channel, :account, :inbox, :conversation, :processed_mail

  FALLBACK_CONVERSATION_PATTERN = %r{account/(\d+)/conversation/([a-zA-Z0-9-]+)@}

  def process(mail, channel)
    @inbound_mail = mail
    @channel = channel
    load_account
    load_inbox
    decorate_mail

    @from_sent_folder = @inbound_mail['X-Chatwoot-Source']&.value == 'sent'

    Rails.logger.info("Processing Email from: #{@processed_mail.original_sender} : inbox #{@inbox.id} : message_id #{@processed_mail.message_id} : source=#{@from_sent_folder ? 'sent' : 'inbox'}")

    if @from_sent_folder
      # Sent folder: only process if sender matches this channel's email
      if sent_from_this_channel?
        process_outgoing_email
      else
        Rails.logger.info("[IMAP::SENT_SKIP] Skipping sent email from #{@processed_mail.original_sender} — doesn't match channel #{@channel.email}")
      end
    elsif sent_from_this_channel?
      # Inbox email from our own address (e.g., bounce or copy) — treat as outgoing
      process_outgoing_email
    else
      # Normal incoming email
      return unless incoming_email_from_valid_email?

      ActiveRecord::Base.transaction do
        find_or_create_contact
        find_or_create_conversation
        create_message
        add_attachments_to_message
      end
    end
  end

  private

  def load_account
    @account = @channel.account
  end

  def load_inbox
    @inbox = @channel.inbox
  end

  def decorate_mail
    @processed_mail = MailPresenter.new(@inbound_mail, @account)
  end

  def find_conversation_by_in_reply_to
    return if in_reply_to.blank?

    message = @inbox.messages.find_by(source_id: in_reply_to)
    if message.nil?
      @inbox.conversations.find_by("additional_attributes->>'in_reply_to' = ?", in_reply_to)
    else
      @inbox.conversations.find(message.conversation_id)
    end
  end

  def find_conversation_by_reference_ids
    return if @inbound_mail.references.blank?

    message = find_message_by_references
    if message.present?
      conversation = @inbox.conversations.find_by(id: message.conversation_id)
      return conversation if conversation.present?
    end

    # FALLBACK_PATTERN use to find a conversation that is started by an agent (no incoming message yet)
    conversation_id = find_conversation_by_references
    @inbox.conversations.find_by(uuid: conversation_id) if conversation_id.present?
  end

  def in_reply_to
    @processed_mail.in_reply_to
  end

  def find_conversation_by_references
    references = Array.wrap(@inbound_mail.references)
    references.each do |message_id|
      match = FALLBACK_CONVERSATION_PATTERN.match(message_id)

      return match[2] if match.present?
    end
  end

  def find_message_by_references
    message_to_return = nil

    references = Array.wrap(@inbound_mail.references)

    references.each do |message_id|
      message = @inbox.messages.find_by(source_id: message_id)
      message_to_return = message if message.present?
    end
    message_to_return
  end

  def find_or_create_conversation
    @conversation = find_conversation_by_in_reply_to || find_conversation_by_reference_ids || ::Conversation.create!(
      {
        account_id: @account.id,
        inbox_id: @inbox.id,
        contact_id: @contact.id,
        contact_inbox_id: @contact_inbox.id,
        additional_attributes: {
          source: 'email',
          in_reply_to: in_reply_to,
          auto_reply: @processed_mail.auto_reply?,
          mail_subject: @processed_mail.subject,
          initiated_at: {
            timestamp: Time.now.utc
          }
        }
      }
    )
  end

  def sent_from_this_channel?
    sender_email = @processed_mail.from&.first&.downcase
    return false if sender_email.blank?

    sender_email == @channel.email&.downcase || sender_email == @channel.imap_login&.downcase
  end

  def find_agent_by_email
    sender_email = @processed_mail.from&.first&.downcase
    @account.users.find_by(email: sender_email) || @account.users.find_by(email: @channel.email&.downcase)
  end

  def find_or_create_contact_from_recipients
    # For sent emails, the contact is the recipient, not the sender
    recipient_email = @processed_mail.to&.first
    return if recipient_email.blank?

    @contact = @inbox.contacts.from_email(recipient_email)
    if @contact.present?
      @contact_inbox = ContactInbox.find_by(inbox: @inbox, contact: @contact)
    else
      @contact_inbox = ::ContactInboxWithContactBuilder.new(
        source_id: recipient_email,
        inbox: @inbox,
        contact_attributes: {
          name: recipient_email.split('@').first.capitalize,
          email: recipient_email
        }
      ).perform
      @contact = @contact_inbox.contact
    end
  end

  def create_outgoing_message
    return if @conversation.messages.find_by(source_id: processed_mail.message_id).present?

    agent = find_agent_by_email
    @message = @conversation.messages.create!(
      account_id: @conversation.account_id,
      sender: agent,
      content: mail_content&.truncate(150_000),
      inbox_id: @conversation.inbox_id,
      message_type: 'outgoing',
      content_type: 'incoming_email',
      source_id: processed_mail.message_id,
      content_attributes: {
        email: processed_mail.serialized_data,
        cc_email: processed_mail.cc,
        bcc_email: processed_mail.bcc
      }
    )
  end

  def process_outgoing_email
    Rails.logger.info("[IMAP::OUTGOING] Processing outgoing email from #{@processed_mail.original_sender} to #{@processed_mail.to&.first} | in_reply_to: #{in_reply_to} | references: #{@inbound_mail.references&.inspect}")

    ActiveRecord::Base.transaction do
      find_or_create_contact_from_recipients
      if @contact.nil?
        Rails.logger.info("[IMAP::OUTGOING] No contact found/created for recipient #{@processed_mail.to&.first}, skipping")
        return
      end

      find_or_create_conversation
      Rails.logger.info("[IMAP::OUTGOING] Conversation #{@conversation.id} (#{@conversation.previously_new_record? ? 'NEW' : 'EXISTING'}) for message #{@processed_mail.message_id}")
      create_outgoing_message
      add_attachments_to_message
    end
  end

  def find_or_create_contact
    @contact = @inbox.contacts.from_email(@processed_mail.original_sender)
    if @contact.present?
      @contact_inbox = ContactInbox.find_by(inbox: @inbox, contact: @contact)
    else
      create_contact
    end
  end

  def identify_contact_name
    processed_mail.sender_name || processed_mail.from.first.split('@').first
  end
end
