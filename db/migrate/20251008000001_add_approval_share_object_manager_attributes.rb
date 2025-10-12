# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddApprovalShareObjectManagerAttributes < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup
    return if !Setting.exists?(name: 'system_init_done')

    UserInfo.current_user_id = 1

    # Add Approval attribute to Ticket object
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

    # Add Share attribute to Ticket object
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

  def down
    # Remove the attributes
    ObjectManager::Attribute.find_by(object_lookup_id: ObjectLookup.by_name('Ticket'), name: 'approvals')&.destroy
    ObjectManager::Attribute.find_by(object_lookup_id: ObjectLookup.by_name('Ticket'), name: 'shares')&.destroy
  end
end
