# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class CleanupCcUserIdsAttribute < ActiveRecord::Migration[7.2]
  def up
    # This migration cleans up the partial cc_user_ids ObjectManager attribute
    # that was created by the failed migration 20250109000004
    
    # Remove from schema_migrations if it exists
    ActiveRecord::Base.connection.execute(
      "DELETE FROM schema_migrations WHERE version = '20250109000004'"
    )
    
    # Remove ObjectManager attribute if it exists
    attr = ObjectManager::Attribute.find_by(
      object_lookup_id: ObjectLookup.by_name('Ticket'),
      name: 'cc_user_ids'
    )
    
    if attr
      Rails.logger.info "[CC_CLEANUP] Removing partial cc_user_ids attribute (ID: #{attr.id})"
      attr.destroy
      Rails.logger.info '[CC_CLEANUP] ✅ Attribute removed'
    else
      Rails.logger.info '[CC_CLEANUP] No cc_user_ids attribute found - already clean'
    end
    
    # Remove column from tickets table if it exists (unlikely but possible)
    if column_exists?(:tickets, :cc_user_ids)
      Rails.logger.info '[CC_CLEANUP] Removing cc_user_ids column from tickets table'
      remove_column :tickets, :cc_user_ids
      Rails.logger.info '[CC_CLEANUP] ✅ Column removed'
    else
      Rails.logger.info '[CC_CLEANUP] No cc_user_ids column - correct (virtual attribute)'
    end
    
    Rails.logger.info '[CC_CLEANUP] ✅ Cleanup complete - system should boot normally now'
  end

  def down
    # No rollback needed - cleanup is permanent
    Rails.logger.info '[CC_CLEANUP] Rollback: No action needed (cleanup is permanent)'
  end
end

