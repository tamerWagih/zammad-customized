# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TransactionDispatcher

  def self.reset
    EventBuffer.reset('transaction')
  end

  def self.commit(params = {})

    # add attribute of interface handle (e. g. to send (no) notifications if a agent
    # is creating a ticket via application_server, but send it if it's created via
    # postmaster)
    params[:interface_handle] = ApplicationHandleInfo.current

    # execute object transactions
    TransactionDispatcher.perform(params)
  end

  def self.perform(params)

    # return if we run import mode
    return if Setting.get('import_mode')

    # get buffer
    list = EventBuffer.list('transaction')
    Rails.logger.info "[TRANSACTION_DISPATCHER] 📥 Processing #{list.count} events from EventBuffer"
    
    # Log all events for debugging
    list.each_with_index do |event, index|
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📋 Event #{index + 1}: #{event[:object]} ##{event[:id]} (#{event[:type]}) - user_id: #{event[:user_id]}"
      if event[:object] == 'Ticket::Approval' || event[:object] == 'Ticket::Share'
        Rails.logger.info "[TRANSACTION_DISPATCHER] 🎯 Found our event: #{event[:object]} ##{event[:id]} (#{event[:type]})"
        Rails.logger.info "[TRANSACTION_DISPATCHER] 📋 Event details: #{event.inspect}"
      end
    end

    # reset buffer
    EventBuffer.reset('transaction')

    # get async backends
    sync_backends = []
    Setting.where(area: 'Transaction::Backend::Sync').reorder(:name).each do |setting|
      backend = Setting.get(setting.name)
      next if params[:disable]&.include?(backend)

      sync_backends.push backend.constantize
    end

    # get uniq objects
    list_objects = get_uniq_changes(list)
    list_objects.each_value do |objects|
      objects.each_value do |item|

        # execute sync backends
        sync_backends.each do |backend|
          execute_single_backend(backend, item, params)
        end

        # execute async backends
        # NOTE: TransactionDispatcher.commit is called AFTER the DB transaction completes (from around_action)
        # So we can safely queue the job directly without wrapping in after_commit
        Rails.logger.info "[TRANSACTION_DISPATCHER] 📤 Queuing TransactionJob for #{item[:object]} ##{item[:object_id]} (#{item[:type]})"
        TransactionJob.perform_later(item, params)
        Rails.logger.info "[TRANSACTION_DISPATCHER] ✅ TransactionJob queued successfully"
      end
    end
  end

  def self.execute_single_backend(backend, item, params)
    Rails.logger.debug { "Execute single backend #{backend}" }
    begin
      UserInfo.current_user_id = nil
      integration = backend.new(item, params)
      integration.perform
    rescue => e
      Rails.logger.error e
    end
  end

=begin

  result = get_uniq_changes(events)

  result = {
    'Ticket' =>
      1 => {
        object: 'Ticket',
        type: 'create',
        object_id: 123,
        article_id: 123,
        user_id: 123,
        created_at: Time.zone.now,
      },
      9 => {
        object: 'Ticket',
        type: 'update',
        object_id: 123,
        changes: {
          attribute1: [before, now],
          attribute2: [before, now],
        },
        user_id: 123,
        created_at: Time.zone.now,
      },
    },
  }

  result = {
    'Ticket' =>
      9 => {
        object: 'Ticket',
        type: 'update',
        object_id: 123,
        article_id: 123,
        changes: {
          attribute1: [before, now],
          attribute2: [before, now],
        },
        user_id: 123,
        created_at: Time.zone.now,
      },
    },
  }

=end

  def self.get_uniq_changes(events)
    list_objects = {}
    events.each do |event|

      # simulate article create as ticket update
      article = nil
      if event[:object] == 'Ticket::Article'
        article = Ticket::Article.find_by(id: event[:id])
        next if !article
        next if event[:type] == 'update'

        # set new event infos
        ticket = Ticket.find_by(id: article.ticket_id)
        event[:object] = 'Ticket'
        event[:id] = ticket.id
        event[:type] = 'update'
        event[:changes] = nil
      end

    # get current state of objects
    # For delete events, use object_id instead of id, and use data from event
    event_id = event[:type] == 'delete' ? event[:object_id] : event[:id]
    Rails.logger.info "[TRANSACTION_DISPATCHER] 🔍 Looking for #{event[:object]} with id: #{event_id}"
    object = event[:object].constantize.find_by(id: event_id)
    Rails.logger.info "[TRANSACTION_DISPATCHER] 📦 Found object: #{object.inspect}"
    
    # Additional debugging for our specific events
    if event[:object] == 'Ticket::Approval' || event[:object] == 'Ticket::Share'
      Rails.logger.info "[TRANSACTION_DISPATCHER] 🎯 Processing our custom event: #{event[:object]} ##{event_id} (#{event[:type]})"
    end

      # For delete events, the object won't exist (already destroyed)
      # Use the serialized data from the event instead
      if !object
        if event[:type] == 'delete' && event[:data]
          Rails.logger.info "[TRANSACTION_DISPATCHER] ✅ Using serialized data for delete event: #{event[:object]} ##{event_id}"
          # Create a minimal struct to satisfy the rest of the logic
          object = OpenStruct.new(id: event_id)
        else
          Rails.logger.warn "[TRANSACTION_DISPATCHER] ⚠️  Object not found: #{event[:object]} ##{event_id} - skipping"
          next
        end
      end

      if !list_objects[event[:object]]
        list_objects[event[:object]] = {}
      end
      if !list_objects[event[:object]][object.id]
        list_objects[event[:object]][object.id] = {}
      end
      store = list_objects[event[:object]][object.id]
      store[:object] = event[:object]
      store[:object_id] = object.id
      store[:user_id] = event[:user_id]
      store[:created_at] = event[:created_at]

      if !store[:type] || store[:type] == 'update'
        store[:type] = event[:type]
      end

      # merge changes
      if event[:changes]
        if store[:changes]
          event[:changes].each do |key, value|
            if store[:changes][key]
              store[:changes][key][1] = value[1]
            else
              store[:changes][key] = value
            end
          end
        else
          store[:changes] = event[:changes]
        end
      end

      # For delete events, include serialized data
      if event[:type] == 'delete' && event[:data]
        store[:data] = event[:data]
      end

      # remember article id if exists
      if article
        store[:article_id] = article.id
      end
    end
    list_objects
  end

  # Used as ActiveRecord lifecycle callback on the class.
  def self.after_create(record)

    # return if we run import mode
    return true if Setting.get('import_mode')

    # Add debugging for our specific models
    if record.class.name == 'Ticket::Approval' || record.class.name == 'Ticket::Share'
      Rails.logger.info "[TRANSACTION_DISPATCHER] 🎯 after_create called for #{record.class.name} ##{record.id}"
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📋 record.created_by_id: #{record.created_by_id}"
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📋 UserInfo.current_user_id: #{UserInfo.current_user_id}"
    end

    e = {
      object:     record.class.name,
      type:       'create',
      data:       record,
      id:         record.id,
      user_id:    record.created_by_id,
      created_at: Time.zone.now,
    }
    EventBuffer.add('transaction', e)
    
    if record.class.name == 'Ticket::Approval' || record.class.name == 'Ticket::Share'
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📨 Event added to EventBuffer for #{record.class.name} ##{record.id} (create)"
    end
    
    true
  end

  # Used as ActiveRecord lifecycle callback on the class.
  def self.after_update(record)

    # return if we run import mode
    return true if Setting.get('import_mode')

    # Add debugging for our specific models
    if record.class.name == 'Ticket::Approval' || record.class.name == 'Ticket::Share'
      Rails.logger.info "[TRANSACTION_DISPATCHER] 🎯 after_update called for #{record.class.name} ##{record.id}"
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📋 record.updated_by_id: #{record.updated_by_id rescue 'N/A'}"
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📋 record.created_by_id: #{record.created_by_id rescue 'N/A'}"
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📋 UserInfo.current_user_id: #{UserInfo.current_user_id}"
    end

    # ignore certain attributes
    real_changes = {}
    record.saved_changes.each do |key, value|
      next if key == 'updated_at'
      next if key == 'article_count'
      next if key == 'create_article_type_id'
      next if key == 'create_article_sender_id'

      real_changes[key] = value
    end

    # do not send anything if nothing has changed
    if real_changes.blank?
      if record.class.name == 'Ticket::Approval' || record.class.name == 'Ticket::Share'
        Rails.logger.info "[TRANSACTION_DISPATCHER] ⚠️ No real changes for #{record.class.name} ##{record.id} - skipping"
      end
      return true
    end

    changed_by_id = if record.respond_to?(:updated_by_id)
                      record.updated_by_id
                    else
                      record.created_by_id
                    end

    if record.class.name == 'Ticket::Approval' || record.class.name == 'Ticket::Share'
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📋 Using changed_by_id: #{changed_by_id}"
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📋 Real changes: #{real_changes.keys.join(', ')}"
    end

    e = {
      object:     record.class.name,
      type:       'update',
      data:       record,
      changes:    real_changes,
      id:         record.id,
      user_id:    changed_by_id,
      created_at: Time.zone.now,
    }
    EventBuffer.add('transaction', e)
    
    if record.class.name == 'Ticket::Approval' || record.class.name == 'Ticket::Share'
      Rails.logger.info "[TRANSACTION_DISPATCHER] 📨 Event added to EventBuffer for #{record.class.name} ##{record.id} (update)"
    end
    
    true
  end

end
