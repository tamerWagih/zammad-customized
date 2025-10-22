# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddCcUsersToTicket < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    # Add cc_user_ids ObjectManager attribute to Ticket
    ObjectManager::Attribute.add(
      force:       true,
      object:      'Ticket',
      name:        'cc_user_ids',
      display:     'CC Users',
      data_type:   'select',
      data_option: {
        null:       true,
        multiple:   true,
        nulloption: true,
        relation:   'User',
        options:    {},
        translate:  false,
        tag:        'cc_user_select',  # Use custom UI element
        permission: ['ticket.agent', 'ticket.customer'],
      },
      editable:    true,
      active:      true,
      screens:     {
        create_middle: {
          'ticket.agent'    => {
            null: true,
            item_class: 'column',
          },
          'ticket.customer' => {
            null: true,
            item_class: 'column',
          },
        },
        edit:          {
          'ticket.agent'    => {
            null: true,
          },
          'ticket.customer' => {
            null: true,
          },
        },
      },
      to_create:   false,
      to_migrate:  false,
      to_delete:   false,
      position:    225,
    )
  end

  def down
    return if !Setting.exists?(name: 'system_init_done')
    
    ObjectManager::Attribute.remove(
      object: 'Ticket',
      name:   'cc_user_ids',
    )
  end
end

