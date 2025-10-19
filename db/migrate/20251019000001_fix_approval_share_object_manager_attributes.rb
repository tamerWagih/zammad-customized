# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class FixApprovalShareObjectManagerAttributes < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    UserInfo.current_user_id = 1

    # Remove the incorrect richtext attributes
    ObjectManager::Attribute.find_by(object_lookup_id: ObjectLookup.by_name('Ticket'), name: 'approvals')&.destroy
    ObjectManager::Attribute.find_by(object_lookup_id: ObjectLookup.by_name('Ticket'), name: 'shares')&.destroy

    # Note: Approvals and Shares are relational objects, not direct attributes
    # They should be managed through trigger actions (approval.create, share.create)
    # not through form fields. The data is accessible via ticket.approvals and ticket.shares associations.
  end

  def down
    # Restore the old richtext attributes if rolling back
    UserInfo.current_user_id = 1

    ObjectManager::Attribute.add(
      force:       true,
      object:      'Ticket',
      name:        'approvals',
      display:     __('Approvals'),
      data_type:   'richtext',
      data_option: {
        type:      'text',
        maxlength: 5000,
        no_images: true,
        null:      true,
        translate: false,
      },
      editable:    false,
      active:      true,
      screens:     {
        create_bottom: {
          'ticket.agent' => {
            null: true,
          },
        },
        edit:          {},
      },
      to_create:   false,
      to_migrate:  false,
      to_delete:   false,
      position:    910,
    )

    ObjectManager::Attribute.add(
      force:       true,
      object:      'Ticket',
      name:        'shares',
      display:     __('Shares'),
      data_type:   'richtext',
      data_option: {
        type:      'text',
        maxlength: 5000,
        no_images: true,
        null:      true,
        translate: false,
      },
      editable:    false,
      active:      true,
      screens:     {
        create_bottom: {
          'ticket.agent' => {
            null: true,
          },
        },
        edit:          {},
      },
      to_create:   false,
      to_migrate:  false,
      to_delete:   false,
      position:    920,
    )
  end
end

