# Email Notification Troubleshooting Guide

## Overview
This guide helps diagnose why approval/share email notifications are not being sent.

---

## System Architecture

### Email Flow:
```
1. User Action (create/approve/reject/etc.)
   ↓
2. Service Layer (app/services/service/ticket/approval/...)
   ↓
3. ActiveRecord Callback (after_create_commit, after_update_commit)
   ↓
4. TriggersNotifications Module (adds event to EventBuffer)
   ↓
5. TransactionDispatcher (processes EventBuffer at end of request)
   ↓
6. TransactionJob (background job - ASYNC)
   ↓
7. ApprovalNotification/ShareNotification Backend
   ↓
8. NotificationFactory::Mailer (sends email via SMTP)
```

---

## Log Markers

### Event Triggers (TriggersNotifications):
- `[APPROVAL_NOTIFICATION] CREATE triggered for approval #X by user #Y`
- `[APPROVAL_NOTIFICATION] Event added to EventBuffer: Ticket::Approval #X (create)`
- `[SHARE_NOTIFICATION] CREATE triggered for share #X by user #Y`
- `[SHARE_NOTIFICATION] Event added to EventBuffer: Ticket::Share #X (create)`

### Backend Execution:
- `[APPROVAL_NOTIFICATION] Backend perform() called for create on approval #X`
- `[APPROVAL_NOTIFICATION] Recipients prepared: N recipient(s)`
- `[APPROVAL_NOTIFICATION] Processing recipient: user@example.com (channels: online, email)`
- `[APPROVAL_NOTIFICATION] Sending email to user@example.com (template: ticket_approval_notification, action: create, ticket: #123)`
- `[APPROVAL_NOTIFICATION] Email sent successfully to user@example.com (create/123)`

### Skip Reasons:
- `Skipped: import_mode enabled`
- `Skipped: approval or ticket not found`
- `Skipped: disable_notification param`
- `Skipped: send_notification=false param`
- `Skipped user@example.com: recipient is sender (myself)`
- `Skipped user@example.com: user inactive`
- `Email skipped for user@example.com: email channel not enabled`
- `Email skipped for user: no email address`

### Errors:
- `could not send approval email notification to agent (create/123/user@example.com) [SMTP error details]`

---

## Diagnostic Steps

### Step 1: Check if Events are Being Triggered
**Location:** `log/development.log`

**Search for:**
```
[APPROVAL_NOTIFICATION] CREATE triggered
[SHARE_NOTIFICATION] CREATE triggered
```

**If NOT found:**
- ✅ Check if `Ticket::Approval` includes `Ticket::Approval::TriggersNotifications`
- ✅ Check if `Ticket::Share` includes `Ticket::Share::TriggersNotifications`
- ✅ Verify ActiveRecord callbacks are not being skipped

**If found, proceed to Step 2.**

---

### Step 2: Check if Events are Added to EventBuffer
**Location:** `log/development.log`

**Search for:**
```
Event added to EventBuffer: Ticket::Approval
Event added to EventBuffer: Ticket::Share
```

**If NOT found:**
- ✅ Check for exceptions in `TriggersNotifications` modules
- ✅ Verify `EventBuffer.add()` is not failing silently

**If found, proceed to Step 3.**

---

### Step 3: Check if TransactionJob is Running
**Location:** `log/development.log`

**Search for:**
```
[APPROVAL_NOTIFICATION] Backend perform() called
[SHARE_NOTIFICATION] Backend perform() called
```

**If NOT found:**
- ❌ **CRITICAL: Background jobs are not running!**

**Solutions:**
1. **Check if Sidekiq/Delayed Job is running:**
   ```bash
   # For Sidekiq:
   ps aux | grep sidekiq
   
   # For Delayed Job:
   ps aux | grep delayed_job
   ```

2. **Start background workers:**
   ```bash
   # For Sidekiq:
   bundle exec sidekiq
   
   # For Delayed Job:
   rake jobs:work
   
   # Or for Zammad:
   script/background-worker.rb start
   ```

3. **Alternative: Force inline execution (development only):**
   Add to `config/environments/development.rb`:
   ```ruby
   config.active_job.queue_adapter = :inline
   ```
   Then restart Rails.

**If found, proceed to Step 4.**

---

### Step 4: Check if Recipients are Being Prepared
**Location:** `log/development.log`

**Search for:**
```
[APPROVAL_NOTIFICATION] Recipients prepared: N recipient(s)
```

**If N = 0:**
- ✅ Check recipient selection logic in `get_recipients` method
- ✅ Verify users are active and have email addresses
- ✅ Check if action performer is being filtered out (myself check)

**Actions to verify:**
- **CREATE**: Sends to approver AND requester
- **APPROVE/REJECT**: Sends to requester only
- **UPDATE**: Sends to approver AND requester
- **DELETE**: Sends to approver (if pending)
- **SHARE CREATE**: Sends to all agents in shared group
- **SHARE REVOKE/UPDATE**: Sends to shared group agents

**If N > 0, proceed to Step 5.**

---

### Step 5: Check if Email Channel is Enabled
**Location:** `log/development.log`

**Search for:**
```
Email skipped for user@example.com: email channel not enabled
```

**If found:**
- ❌ **User has email notifications disabled**

**Solution:**
1. Go to **Admin → Users → [Select User]**
2. Check **Notifications** settings
3. Enable **Email** channel for ticket notifications

**If not found, proceed to Step 6.**

---

### Step 6: Check if SMTP is Configured
**Location:** `log/development.log`

**Search for:**
```
[APPROVAL_NOTIFICATION] Sending email to user@example.com
```

**If found but NO success message:**
- ❌ **SMTP configuration issue or delivery error**

**Check for errors:**
```
could not send approval email notification
Channel::DeliveryError
```

**Solutions:**

1. **Verify SMTP settings in Zammad:**
   - Go to **Admin → Channels → Email → Accounts**
   - Check outbound email settings
   - Test email sending

2. **Common SMTP issues:**
   - Wrong host/port
   - Authentication failure
   - TLS/SSL configuration
   - Firewall blocking port 25/587/465

3. **Test SMTP manually:**
   ```ruby
   # Rails console
   ActionMailer::Base.mail(
     from: 'zammad@example.com',
     to: 'test@example.com',
     subject: 'Test',
     body: 'Test email'
   ).deliver_now
   ```

4. **Check Rails SMTP configuration:**
   ```ruby
   # Rails console
   ActionMailer::Base.delivery_method
   ActionMailer::Base.smtp_settings
   ```

**If success message found, proceed to Step 7.**

---

### Step 7: Verify Email Was Sent
**Location:** `log/development.log`

**Search for:**
```
[APPROVAL_NOTIFICATION] Email sent successfully to user@example.com
```

**If found:**
✅ **Email was sent successfully!**

**Next steps:**
1. Check recipient's spam/junk folder
2. Check email server logs
3. Verify recipient email address is correct
4. Check if email is being filtered by corporate firewall/gateway

---

## Quick Reference: Log Grep Commands

```bash
# Check if events are being triggered
tail -f log/development.log | grep "NOTIFICATION.*triggered"

# Check if events are added to buffer
tail -f log/development.log | grep "Event added to EventBuffer"

# Check if backends are executing
tail -f log/development.log | grep "Backend perform"

# Check if emails are being sent
tail -f log/development.log | grep "Sending email"

# Check for errors
tail -f log/development.log | grep -i "error\|exception\|failed"

# Full notification flow for a specific action
tail -f log/development.log | grep "APPROVAL_NOTIFICATION\|SHARE_NOTIFICATION"
```

---

## Common Issues & Solutions

### Issue: No logs at all
**Cause:** Callbacks not triggered
**Solution:** Check if models include `TriggersNotifications` modules

### Issue: Events triggered but backend never executes
**Cause:** Background workers not running
**Solution:** Start Sidekiq/Delayed Job or use inline queue adapter

### Issue: Backend executes but 0 recipients
**Cause:** User filtering or notification settings
**Solution:** Check user notification preferences and recipient logic

### Issue: Email channel disabled for all users
**Cause:** Default notification settings
**Solution:** Enable email channel in user preferences or system defaults

### Issue: SMTP errors
**Cause:** SMTP misconfiguration
**Solution:** Verify SMTP settings in Admin panel

### Issue: Email sent but not received
**Cause:** Spam filtering, wrong email address
**Solution:** Check spam folder, verify email address

---

## Testing Email Notifications

### Manual Test (Rails Console):

```ruby
# Create test approval
approval = Ticket::Approval.create!(
  ticket_id: 1,
  approver_id: 2,
  requester_id: 3,
  status: 'pending',
  message: 'Test approval'
)

# Check logs for:
# - [APPROVAL_NOTIFICATION] CREATE triggered for approval #X
# - [APPROVAL_NOTIFICATION] Event added to EventBuffer
# - [APPROVAL_NOTIFICATION] Backend perform() called
# - [APPROVAL_NOTIFICATION] Email sent successfully
```

### Verify Transaction Settings:

```ruby
# Rails console
Setting.get('0110_approval_notification')
# => "Transaction::ApprovalNotification"

Setting.get('0120_share_notification')
# => "Transaction::ShareNotification"
```

### Check if Backends are Registered:

```ruby
# Rails console
Setting.where(area: 'Transaction::Backend::Async').pluck(:name, :state)
# Should include:
# ["0110_approval_notification", "Transaction::ApprovalNotification"]
# ["0120_share_notification", "Transaction::ShareNotification"]
```

---

## Need More Help?

If you've followed all steps and emails are still not sending:

1. **Capture full log output:**
   ```bash
   tail -100 log/development.log > email-debug.log
   ```

2. **Check for any exceptions in the full log**

3. **Verify Zammad core email notifications work** (create a ticket, add an article, check if customer gets email)

4. **If Zammad core emails work but approval/share don't:** Review the transaction backend registration in `db/seeds/settings.rb`

---

## Summary Checklist

- [ ] Events are triggered (TriggersNotifications)
- [ ] Events added to EventBuffer
- [ ] Background workers running (Sidekiq/Delayed Job)
- [ ] Transaction backends executing
- [ ] Recipients being prepared (count > 0)
- [ ] Email channel enabled for users
- [ ] SMTP configured correctly
- [ ] Email sent successfully
- [ ] Email received (check spam)

If all checkboxes are ✅ but still no email, the issue is likely with the email server or recipient's email provider.

