# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Add CC Users field to Ticket form
# This is done in seeds (not migration) because:
# 1. cc_user_ids is a virtual attribute (attr_accessor), not a DB column
# 2. ObjectManager.add creates attribute definition but expects real DB column
# 3. Running in seeds allows ObjectManager to be fully initialized first

return if !Setting.exists?(name: 'system_init_done')

UserInfo.current_user_id = 1

# Check if attribute already exists
existing_attr = ObjectManager::Attribute.find_by(
  object_lookup_id: ObjectLookup.by_name('Ticket'),
  name: 'cc_user_ids'
)

if existing_attr
  Rails.logger.info '[CC_SEED] CC Users attribute already exists, updating...'
  existing_attr.destroy
end

# Add cc_user_ids field to Ticket form
ObjectManager::Attribute.add(
  force:       true,
  object:      'Ticket',
  name:        'cc_user_ids',
  display:     'CC Users',
  data_type:   'select',
  data_option: {
    default:    '',
    null:       true,
    multiple:   true,
    nulloption: true,
    relation:   'User',
    options:    {},
    translate:  false,
    tag:        'cc_user_select',
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
  created_by_id: 1,
  updated_by_id: 1,
)

# Execute ObjectManager migrations to add the column
ObjectManager::Attribute.migration_execute

Rails.logger.info '[CC_SEED] ✅ CC Users field added to Ticket form'

