class Api::V1::Accounts::InternalContactsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    internal_inbox = Current.account.inboxes.find_by(channel_type: 'Channel::Internal')

    render json: [] and return unless internal_inbox

    agents = Current.account.users.includes(:contacts).map do |user|
      shadow_contact = Current.account.contacts.find_by(shadow_user_id: user.id)
      next unless shadow_contact

      {
        id: user.id,
        name: user.available_name || user.name,
        avatar_url: user.avatar_url,
        shadow_contact_id: shadow_contact.id
      }
    end.compact

    render json: agents
  end

  private

  def check_authorization
    authorize :internal_contact
  end
end
