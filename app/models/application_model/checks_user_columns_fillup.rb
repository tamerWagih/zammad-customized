# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module ApplicationModel::ChecksUserColumnsFillup
  extend ActiveSupport::Concern

  included do
    before_validation :fill_up_user_validate
  end

  def fill_up_user_validate
    return fill_up_user_create if new_record?

    fill_up_user_update
  end

=begin

set created_by_id & updated_by_id if not given based on UserInfo (current session)

Used as before_create callback, no own use needed

  result = Model.fill_up_user_create(params)

returns

  result = params # params with updated_by_id & created_by_id if not given based on UserInfo (current session)

=end

  def fill_up_user_create
    # Add debugging for our specific models
    if self.class.name == 'Ticket::Approval' || self.class.name == 'Ticket::Share'
      Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] 🎯 fill_up_user_create called for #{self.class.name}"
      Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] 📋 UserInfo.current_user_id: #{UserInfo.current_user_id}"
      Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] 📋 Has updated_by_id column: #{self.class.column_names.include?('updated_by_id')}"
      Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] 📋 Has created_by_id column: #{self.class.column_names.include?('created_by_id')}"
    end

    if self.class.column_names.include?('updated_by_id') && UserInfo.current_user_id
      if updated_by_id && updated_by_id != UserInfo.current_user_id
        logger.info "NOTICE create - self.updated_by_id is different: #{updated_by_id}/#{UserInfo.current_user_id}"
      end
      self.updated_by_id = UserInfo.current_user_id
      if self.class.name == 'Ticket::Approval' || self.class.name == 'Ticket::Share'
        Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] ✅ Set updated_by_id to #{UserInfo.current_user_id}"
      end
    end

    return true if self.class.column_names.exclude?('created_by_id')

    return true if !UserInfo.current_user_id

    if created_by_id && created_by_id != UserInfo.current_user_id
      logger.info "NOTICE create - self.created_by_id is different: #{created_by_id}/#{UserInfo.current_user_id}"
    end
    self.created_by_id = UserInfo.current_user_id
    if self.class.name == 'Ticket::Approval' || self.class.name == 'Ticket::Share'
      Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] ✅ Set created_by_id to #{UserInfo.current_user_id}"
    end
    true
  end

=begin

set updated_by_id if not given based on UserInfo (current session)

Used as before_update callback, no own use needed

  result = Model.fill_up_user_update(params)

returns

  result = params # params with updated_by_id & created_by_id if not given based on UserInfo (current session)

=end

  def fill_up_user_update
    # Add debugging for our specific models
    if self.class.name == 'Ticket::Approval' || self.class.name == 'Ticket::Share'
      Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] 🎯 fill_up_user_update called for #{self.class.name}"
      Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] 📋 UserInfo.current_user_id: #{UserInfo.current_user_id}"
      Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] 📋 Has updated_by_id column: #{self.class.column_names.include?('updated_by_id')}"
    end

    return true if self.class.column_names.exclude?('updated_by_id')
    return true if !UserInfo.current_user_id

    self.updated_by_id = UserInfo.current_user_id
    if self.class.name == 'Ticket::Approval' || self.class.name == 'Ticket::Share'
      Rails.logger.info "[CHECKS_USER_COLUMNS_FILLUP] ✅ Set updated_by_id to #{UserInfo.current_user_id}"
    end
    true
  end
end
