# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Trigger Transaction notifications for approval actions
# NOTE: This module is kept for compatibility but does nothing.
# HasTransactionDispatcher automatically handles all create/update notifications.
module Ticket::Approval::TriggersNotifications
  extend ActiveSupport::Concern

  # No callbacks needed - HasTransactionDispatcher handles everything automatically
  # This module is kept for potential future custom logic but currently does nothing
  
  private

  # All notification handling is now done automatically by HasTransactionDispatcher
  # No manual EventBuffer.add calls needed - Zammad handles this automatically
end

