# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Ensure CC Notification backend is registered
module CcNotificationBackendRegistration
  def self.register!
    Rails.logger.info '[CC_BACKEND] Checking CC Notification backend registration...'
    
    setting = Setting.find_by(name: '9300_cc_notification')
    
    if setting
      Rails.logger.info '[CC_BACKEND] ✅ CC notification backend already registered'
      Rails.logger.info "[CC_BACKEND]    State: #{setting.state}"
    else
      Rails.logger.info '[CC_BACKEND] ⚠️  CC notification backend NOT found, registering...'
      
      Setting.create_if_not_exists(
        title:       'Defines transaction backend for CC notifications.',
        name:        '9300_cc_notification',
        area:        'Transaction::Backend::Async',
        description: 'Defines the transaction backend to send CC-related notifications.',
        options:     {},
        state:       'Transaction::CcNotification',
        frontend:    false
      )
      
      Rails.logger.info '[CC_BACKEND] ✅ CC notification backend registered successfully'
    end
    
    # List all async backends
    Rails.logger.info '[CC_BACKEND] All registered Transaction::Backend::Async backends:'
    Setting.where(area: 'Transaction::Backend::Async').reorder(:name).each do |s|
      Rails.logger.info "[CC_BACKEND]    #{s.name} => #{s.state}"
    end
  end
end

# Auto-register on load in development/production
if Rails.env.development? || Rails.env.production?
  Rails.application.config.after_initialize do
    CcNotificationBackendRegistration.register!
  end
end

