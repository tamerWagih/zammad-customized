# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Ticket::PerformChanges
  extend ActiveSupport::Concern

  include CanPerformChanges

  included do
    available_perform_change_actions :delete,
                                     :data_privacy_deletion_task,
                                     :attribute_updates,
                                     :notification_email,
                                     :notification_sms,
                                     :notification_webhook,
                                     :article_note,
                                     :approval_create,
                                     :share_create
  end

  def pre_execute(perform_changes_data)
    article = begin
      Ticket::Article.find_by(id: perform_changes_data[:context_data].try(:dig, :article_id))
    rescue ArgumentError
      nil
    end

    return if article.nil?

    perform_changes_data[:context_data][:article] = article
  end

  def additional_object_action(object_name, object_key, action_value, _prepared_actions)
    # Handle article actions
    if object_name == 'article' && %w[note].include?(object_key)
      return { name: :"article_#{object_key.to_sym}", value: action_value }
    end

    # Handle approval actions
    if object_name == 'approval' && %w[create].include?(object_key)
      return { name: :"approval_#{object_key.to_sym}", value: action_value }
    end

    # Handle share actions
    if object_name == 'share' && %w[create].include?(object_key)
      return { name: :"share_#{object_key.to_sym}", value: action_value }
    end

    nil
  end
end
