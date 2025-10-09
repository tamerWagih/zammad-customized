# Email Notification System - Complete Analysis

## 📋 **How Zammad Email Notifications Work (Native Flow)**

### **1. Model Change → EventBuffer**
```ruby
# In Ticket model:
include HasTransactionDispatcher

# When ticket.save! happens:
HasTransactionDispatcher → after_create/after_update callbacks
  ↓
TransactionDispatcher.after_create(record)
  ↓
EventBuffer.add('transaction', {
  object: 'Ticket',
  type: 'create',
  object_id: 123,
  user_id: current_user.id,
  changes: {...}
})
```

### **2. EventBuffer → TransactionDispatcher**
```ruby
# At end of request cycle:
TransactionDispatcher.perform
  ↓
Read events from EventBuffer.list('transaction')
  ↓
For each event:
  - Execute SYNC backends immediately
  - Queue ASYNC backends via TransactionJob.perform_later(item, params)
```

### **3. TransactionJob → Notification Backends**
```ruby
# Background worker (Sidekiq) picks up job:
TransactionJob.perform(item, params)
  ↓
Load backends from Settings.where(area: 'Transaction::Backend::Async')
  ↓
For each backend (e.g., Transaction::Notification):
  backend.new(item, params).perform
```

### **4. Notification Backend → Email**
```ruby
Transaction::Notification.perform
  ↓
prepare_recipients_and_reasons
  - Get possible recipients (group users, owner, mentions)
  - Filter by notification_settings (checks user preferences)
  ↓
send_to_single_recipient(user, channels)
  - Check if email channel enabled
  - Call NotificationFactory::Mailer.notification(template, user, objects)
  ↓
Email sent! 📧
```

---

## 📋 **Our Approval/Share Implementation**

### **Models:**
```ruby
# app/models/ticket/approval.rb
class Ticket::Approval < ApplicationModel
  include HasTransactionDispatcher              # ✅ Triggers EventBuffer
  include ChecksClientNotification               # ✅ WebSocket events
  include Ticket::Approval::TriggersNotifications   # Empty (HasTransactionDispatcher handles it)
  include Ticket::Approval::TriggersSubscriptions   # Custom WebSocket broadcasts
end

# app/models/ticket/share.rb  
# Same pattern ✅
```

### **Notification Backends:**
```ruby
# app/models/transaction/approval_notification.rb
class Transaction::ApprovalNotification
  def perform
    # Get recipients (approver, requester)
    # Filter by notification_settings(user, ticket, 'approval')
    # Send emails to recipients
  end
end

# app/models/transaction/share_notification.rb
# Same pattern ✅
```

---

## ✅ **Checklist - What We Fixed**

| Component | Status | Notes |
|-----------|--------|-------|
| **HasTransactionDispatcher** | ✅ | Included in both models |
| **EventBuffer events** | ✅ | Created on create/update/delete |
| **Notification backends exist** | ✅ | ApprovalNotification, ShareNotification |
| **Backends registered in Settings** | ✅ | Migration #1 (20251009000001) |
| **Default notification matrix** | ✅ | Migration #0005 adds 'approval', 'share' |
| **Existing users updated** | ✅ | Migration #2 (20251009000002) |
| **Notification type correct** | ✅ | Using 'approval'/'share' not 'create'/'update' |
| **Delete event data** | ✅ | Includes serialized data for deleted records |
| **Comprehensive logging** | ✅ | Shows recipients, channels, email details |

---

## 🔍 **Comparison: Native vs Custom**

### **Native Ticket Notification:**
```ruby
Transaction::Notification
  ↓
Checks: @item[:object] in ['Ticket', 'Ticket::Article']
  ↓
Recipients: Group users + owner + mentions
  ↓
Filter: notification_settings(user, ticket, 'create' or 'update')
  ↓
Matrix key: matrix['create'] or matrix['update'] ✅ (exists in defaults)
```

### **Our Approval Notification:**
```ruby
Transaction::ApprovalNotification
  ↓
Checks: approval exists, ticket exists
  ↓
Recipients: Approver + requester (based on action type)
  ↓
Filter: notification_settings(user, ticket, 'approval') ✅ (NOW CORRECT!)
  ↓
Matrix key: matrix['approval'] ✅ (added by migrations)
```

---

## 🐛 **Issues Found and Fixed**

### **Issue #1: Backends Not Registered**
**Problem:** TransactionJob couldn't find our backends  
**Fix:** Migration `20251009000001` registers them in Settings  
**Commit:** `df61ebd2fb`

### **Issue #2: Wrong Notification Type**
**Problem:** Using `'create'`, `'update'` instead of `'approval'`, `'share'`  
**Fix:** Changed `notification_settings(user, ticket, 'approval')`  
**Commit:** `7f4fb233c8`

### **Issue #3: Existing Users Missing Matrix Entries**
**Problem:** Old users don't have 'approval'/'share' in preferences  
**Fix:** Migration `20251009000002` updates all existing agent users  
**Commit:** `b3f3cd6ac6`

### **Issue #4: Delete Event Missing Data**
**Problem:** Deleted records can't be found when notification runs  
**Fix:** Add serialized data to EventBuffer, use OpenStruct in notification  
**Commit:** `7b38b49a86`

---

## 🧪 **Testing Email Notifications**

### **After Migrations Run:**

**Check if backends are registered:**
```bash
docker exec -it zammad-container bundle exec rails c
```
```ruby
Setting.where(area: 'Transaction::Backend::Async').pluck(:name, :state)
# Should include:
# ["9100_approval_notification", "Transaction::ApprovalNotification"]
# ["9200_share_notification", "Transaction::ShareNotification"]
```

**Check if users have approval/share in matrix:**
```ruby
user = User.find_by(email: 'test.it@octopusbpo.com')
user.preferences['notification_config']['matrix'].keys
# Should include: 'approval', 'share'
```

**Test notifications:**
1. Create approval
2. Check logs:
```bash
docker logs --tail 100 container | grep APPROVAL_NOTIFICATION
```

**Expected:**
```
[APPROVAL_NOTIFICATION] 🔄 Backend perform() called for create
[APPROVAL_NOTIFICATION] 📋 Possible recipients: approver@example.com, requester@example.com
[APPROVAL_NOTIFICATION] 📋 Final recipients: approver@example.com
[APPROVAL_NOTIFICATION] 📧 Sending email to approver@example.com
[APPROVAL_NOTIFICATION] ✅ Email sent successfully
```

---

## 📊 **Expected Behavior After All Fixes**

| Action | Approver Email | Requester Email | Online Notification |
|--------|----------------|-----------------|---------------------|
| Create Approval | ✅ Sent | ✅ Sent | ✅ Sent |
| Edit Approval | ✅ Sent | ✅ Sent | ✅ Sent |
| Approve | ❌ No | ✅ Sent | ✅ Sent |
| Reject | ❌ No | ✅ Sent | ✅ Sent |
| Delete Approval | ✅ Sent (if pending) | ❌ No | ✅ Sent |
| Create Share | ✅ All group agents | ❌ No | ✅ Sent |
| Edit Share | ✅ All group agents | ❌ No | ✅ Sent |
| Revoke Share | ✅ All group agents | ❌ No | ✅ Sent |
| Delete Share | ✅ All group agents | ❌ No | ✅ Sent |

---

## 🔧 **Troubleshooting**

### **No Logs at All**
- Check if migration #1 ran (backends registered)
- Check if zammad-scheduler container is running
- Check background job processor logs

### **Logs Show "Skipped: approval or ticket not found"**
- For delete operations, check if `data` field is in EventBuffer
- Check if notification backend uses OpenStruct for delete

### **Logs Show "Final recipients: (empty)"**
- Check if users have 'approval'/'share' in notification matrix
- Run migration #2 to update existing users
- Check user's notification preferences in UI

### **Logs Show "Email skipped: email channel not enabled"**
- User has disabled email in their notification preferences
- Check matrix['approval']['channel']['email']

---

**Last Updated:** 2025-10-09  
**All fixes applied:** Commits up to `b3f3cd6ac6`

