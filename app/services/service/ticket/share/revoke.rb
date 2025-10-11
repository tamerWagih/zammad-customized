class Service::Ticket::Share::Revoke < Service::BaseWithCurrentUser
  def execute(share:)
    Pundit.authorize current_user, share.ticket, :update?
    ensure_manageable!(share)

    # Use specific method to trigger proper action type
    share.revoke! unless share.status == 'revoked'
    share.reload

    # Transaction::ShareNotification will be triggered automatically via callbacks
    # The callback will detect status change to 'revoked' and send revoke notification

    share
  end

  private

  def ensure_manageable!(share)
    return if share.shared_by_id == current_user.id || current_user.permissions?('admin')

    raise Exceptions::Forbidden, __('You can only revoke shares you created.')
  end
end
