# Zammad Custom Features - Testing Plan & Checklist

**Version:** 1.0  
**Date:** November 2025  
**Test Environment:** Production-like staging environment  
**Testers:** QA Team / Product Owner

---

## 📋 Table of Contents
1. [Test Environment Setup](#test-environment-setup)
2. [User Roles & Test Accounts](#user-roles--test-accounts)
3. [Feature 1: Ticket Approval System](#feature-1-ticket-approval-system)
4. [Feature 2: Ticket Sharing System](#feature-2-ticket-sharing-system)
5. [Feature 3: CC (Carbon Copy) System](#feature-3-cc-carbon-copy-system)
6. [Feature 4: Agent Creates Ticket for Customer](#feature-4-agent-creates-ticket-for-customer)
7. [Feature 5: Custom Ticket Views](#feature-5-custom-ticket-views)
8. [Feature 6: Grouped Overview Collapse/Expand](#feature-6-grouped-overview-collapseexpand)
9. [Cross-Feature Integration Tests](#cross-feature-integration-tests)
10. [Notifications Testing](#notifications-testing)
11. [Permissions & Security Testing](#permissions--security-testing)
12. [UI/UX Testing](#uiux-testing)
13. [Performance & Error Handling](#performance--error-handling)

---

## Test Environment Setup

### Prerequisites
- [ ] Test environment is running and accessible
- [ ] Database has been migrated to latest version
- [ ] Rails server has been restarted after deployment
- [ ] Test users have been created with proper permissions
- [ ] Email delivery is configured and working
- [ ] WebSocket connections are functioning

### Required Test Groups
- [ ] **Group A** (Sales Department)
- [ ] **Group B** (Support Department)
- [ ] **Group C** (Technical Department)

---

## User Roles & Test Accounts

### Test Users to Create

| Username | Email | Role | Groups | Purpose |
|----------|-------|------|--------|---------|
| admin_test | admin@test.com | Admin | All | Full system access |
| agent_sales | agent.sales@test.com | Agent | Sales | Primary test agent |
| agent_support | agent.support@test.com | Agent | Support | Secondary test agent |
| agent_tech | agent.tech@test.com | Agent | Technical | Third test agent |
| customer1 | customer1@test.com | Customer | None | Customer testing |
| customer2 | customer2@test.com | Customer | None | Secondary customer |

**Setup Checklist:**
- [ ] All test users created
- [ ] Email addresses are valid and accessible
- [ ] Notification preferences are enabled (Email + Online)
- [ ] Users can log in successfully

---

## Feature 1: Ticket Approval System

### 1.1 Create Approval Request

**Test Case:** Agent requests approval from another agent

**Steps:**
1. Log in as `agent_sales`
2. Open any ticket in Group A (Sales)
3. Click on "Approvals" widget in the right sidebar
4. Click "Request Approval" button
5. Fill in the approval form:
   - **Approver:** Select `agent_support`
   - **Message:** "Please approve this customer discount request"
   - **Priority:** Select "High"
6. Click "Request Approval"

**Expected Results:**
- [ ] Approval request appears in the sidebar immediately
- [ ] Status shows "Pending"
- [ ] Priority badge shows "High" in red/orange
- [ ] Online notification appears for `agent_support`
- [ ] Email notification sent to `agent_support`
- [ ] Email subject includes "Approval Request"
- [ ] Email body contains the message
- [ ] Requester name shows correctly
- [ ] Created date is displayed

**Edge Cases:**
- [ ] Try requesting approval from the same approver twice (should show error)
- [ ] Try requesting approval from a customer (should show error or filter customers)
- [ ] Try creating approval without selecting an approver (validation error)

---

### 1.2 View Approval Request (Approver Side)

**Test Case:** Approver can see the request

**Steps:**
1. Log in as `agent_support` (the approver)
2. Check online notifications (bell icon)
3. Click on the approval notification
4. Navigate to the ticket
5. Open "Approvals" widget

**Expected Results:**
- [ ] Approval card is displayed
- [ ] Shows "Request from [agent_sales name]"
- [ ] Message is visible
- [ ] Priority is shown
- [ ] "Approve" and "Reject" buttons are visible
- [ ] No "Edit" or "Delete" buttons (requester only)
- [ ] Ticket is accessible (approver has permission to view)

---

### 1.3 Approve Request

**Test Case:** Approver approves the request

**Steps:**
1. As `agent_support`, click "Approve" button
2. Confirm the action if prompted

**Expected Results:**
- [ ] Status changes to "Approved" immediately
- [ ] Status badge turns green
- [ ] Approve/Reject buttons disappear
- [ ] Online notification sent to `agent_sales` (requester)
- [ ] Email notification sent to `agent_sales`
- [ ] Email subject includes "Approved"
- [ ] History entry added to ticket
- [ ] Real-time update on requester's screen (if they have ticket open)

---

### 1.4 Reject Request

**Test Case:** Approver rejects the request

**Setup:**
1. Create another approval request (agent_sales → agent_tech)

**Steps:**
1. Log in as `agent_tech`
2. Open the ticket with pending approval
3. Click "Reject" button

**Expected Results:**
- [ ] Status changes to "Rejected" immediately
- [ ] Status badge turns red
- [ ] Approve/Reject buttons disappear
- [ ] Online notification sent to requester
- [ ] Email notification sent to requester
- [ ] Email subject includes "Rejected"
- [ ] History entry added to ticket

---

### 1.5 Edit Approval Request (Pending Only)

**Test Case:** Requester can edit their pending request

**Setup:**
1. Create a new approval request (agent_sales → agent_support)

**Steps:**
1. As `agent_sales` (requester), open the ticket
2. In Approvals widget, click "Edit" button
3. Change message to "Updated: Please review urgently"
4. Change priority to "Urgent"
5. Click "Update"

**Expected Results:**
- [ ] Message updates immediately
- [ ] Priority badge changes to "Urgent"
- [ ] Online notification sent to approver about update
- [ ] Email sent to approver
- [ ] History entry shows "Approval request updated"

---

### 1.6 Delete Approval Request

**Test Case:** Requester can delete PENDING approval, but NOT approved/rejected

**Part A: Delete Pending Approval**

**Steps:**
1. Create approval request (agent_sales → agent_support)
2. As `agent_sales`, click "Delete" button
3. Confirm deletion

**Expected Results:**
- [ ] Approval card disappears immediately
- [ ] Confirmation modal shows before deletion
- [ ] Online notification sent to approver
- [ ] Email sent to approver about cancellation
- [ ] History entry added

**Part B: Cannot Delete Approved/Rejected** ⚠️ **CRITICAL**

**Steps:**
1. Create approval and have it approved by approver
2. As requester, check the Approvals widget

**Expected Results:**
- [ ] **Delete button is HIDDEN** for approved requests
- [ ] **Delete button is HIDDEN** for rejected requests
- [ ] Only pending requests show Edit/Delete buttons

---

### 1.7 Permissions Testing

**Test Case:** Only authorized users can approve

**Steps:**
1. Create approval (agent_sales → agent_support)
2. Log in as `agent_tech` (NOT the approver)
3. Try to access the ticket
4. Check if Approve/Reject buttons appear

**Expected Results:**
- [ ] Approve/Reject buttons are NOT visible to other agents
- [ ] Only the assigned approver sees action buttons
- [ ] Requester sees Edit/Delete (if pending)

---

### 1.8 Multiple Approvals on Same Ticket

**Test Case:** Multiple approval requests can exist

**Steps:**
1. As `agent_sales`, create approval request to `agent_support`
2. Create another approval request to `agent_tech`

**Expected Results:**
- [ ] Both approval cards appear in the sidebar
- [ ] Each has independent status
- [ ] No conflicts or errors
- [ ] Each approver gets their own notification

---

## Feature 2: Ticket Sharing System

### 2.1 Share Ticket with Another Group

**Test Case:** Agent shares ticket with another department

**Steps:**
1. Log in as `agent_sales`
2. Create or open a ticket in Group A (Sales)
3. Click on "Share" widget in sidebar
4. Click "Share Ticket" button
5. Select "Support Department" (Group B)
6. Add optional message: "Please assist with technical details"
7. Click "Share"

**Expected Results:**
- [ ] Share appears in the sidebar immediately
- [ ] Shows shared group name
- [ ] Shows "Shared by [name]"
- [ ] Status shows "Active"
- [ ] Online notifications sent to all agents in Support group
- [ ] Email notifications sent to all Support agents
- [ ] Shared ticket appears in Support group's ticket list

---

### 2.2 Shared Ticket Access (Receiver)

**Test Case:** Agents in shared group can access ticket

**Steps:**
1. Log in as `agent_support` (member of Support group)
2. Check ticket overviews
3. Verify the shared ticket appears
4. Open the ticket

**Expected Results:**
- [ ] Ticket is visible in ticket list
- [ ] Ticket opens successfully
- [ ] Agent can read ticket details
- [ ] Agent can add comments/articles
- [ ] Agent CANNOT change ticket owner (comment-only by default)
- [ ] Agent CANNOT close ticket (limited permissions)

---

### 2.3 Share Permissions Levels

**Test Case:** Verify permission differences

**Scenario A: Receiver from SAME group as ticket**

**Steps:**
1. Create ticket in Sales group (owner: Sales)
2. Share with Sales group
3. Have another Sales agent access it

**Expected Results:**
- [ ] Full access (read, comment, edit, close)

**Scenario B: Receiver from DIFFERENT group**

**Steps:**
1. Create ticket in Sales group
2. Share with Support group
3. Have Support agent access it

**Expected Results:**
- [ ] Read access: ✅
- [ ] Comment access: ✅
- [ ] Edit/Close access: ❌ (comment-only)

---

### 2.4 Update/Edit Share

**Test Case:** Share creator can edit share details

**Steps:**
1. As `agent_sales`, open a ticket with active share
2. Click "Edit" on the share card
3. Update message to "Updated: Please prioritize"
4. Click "Update"

**Expected Results:**
- [ ] Message updates immediately
- [ ] Online notification sent to shared group
- [ ] Email sent to shared group
- [ ] History entry added

---

### 2.5 Revoke Share

**Test Case:** Share creator can revoke access

**Steps:**
1. As `agent_sales`, click "Revoke" on active share
2. Confirm revocation

**Expected Results:**
- [ ] Status changes to "Revoked"
- [ ] Shared group loses access to ticket
- [ ] Ticket disappears from shared group's list
- [ ] Online notification sent
- [ ] Email sent to shared group
- [ ] History entry added

---

### 2.6 Delete Share

**Test Case:** Delete share record entirely

**Steps:**
1. Create share, then revoke it
2. Click "Delete" button
3. Confirm deletion

**Expected Results:**
- [ ] Share card disappears
- [ ] Confirmation modal appears
- [ ] History entry added

---

### 2.7 Share Multiple Groups

**Test Case:** Share same ticket with multiple groups

**Steps:**
1. Share ticket with Support group
2. Share same ticket with Technical group

**Expected Results:**
- [ ] Both shares appear in sidebar
- [ ] Each share is independent
- [ ] Both groups have access
- [ ] No conflicts

---

## Feature 3: CC (Carbon Copy) System

### 3.1 Add CC During Ticket Creation

**Test Case:** Add CC users when creating ticket

**Steps:**
1. Log in as `agent_sales`
2. Click "New Ticket"
3. Fill in ticket details:
   - Customer: `customer1@test.com`
   - Group: Sales
   - Subject: "Test CC functionality"
4. In CC field, add:
   - `agent_support@test.com`
   - `agent_tech@test.com`
5. Click "Submit"

**Expected Results:**
- [ ] Ticket created successfully
- [ ] CC widget shows both CC'd users
- [ ] Each CC user receives online notification
- [ ] Each CC user receives email notification
- [ ] CC'd users can see ticket in their overview
- [ ] History shows "CC added" entries

---

### 3.2 Add CC to Existing Ticket

**Test Case:** Add CC after ticket creation

**Steps:**
1. Open existing ticket
2. Click on "CC" widget
3. Click "Add CC"
4. Select or type `agent_tech@test.com`
5. Click "Add"

**Expected Results:**
- [ ] User appears in CC list immediately
- [ ] Online notification sent to CC'd user
- [ ] Email sent to CC'd user
- [ ] User can access the ticket
- [ ] History entry added

---

### 3.3 CC User Access & Permissions

**Test Case:** Verify CC users have appropriate access

**Steps:**
1. Create ticket in Sales group
2. CC `agent_support` (from Support group)
3. Log in as `agent_support`
4. Find and open the ticket

**Expected Results:**
- [ ] Ticket is visible in overview
- [ ] Can read all ticket details
- [ ] Can add comments/articles
- [ ] **Permissions based on user role:**
  - **Agent:** Full access (read, comment, edit)
  - **Customer:** Read + comment only

---

### 3.4 Remove CC

**Test Case:** Remove CC from ticket

**Steps:**
1. In CC widget, click "Remove" (X icon) next to a CC user
2. Confirm removal

**Expected Results:**
- [ ] User removed from CC list
- [ ] User loses access to ticket (if not in ticket's group)
- [ ] Online notification sent to removed user
- [ ] Email sent to removed user
- [ ] History entry added

---

### 3.5 CC with Customer Role

**Test Case:** Add customer as CC

**Steps:**
1. Create ticket
2. Add `customer2@test.com` as CC

**Expected Results:**
- [ ] Customer appears in CC list
- [ ] Customer receives notification
- [ ] Customer can view ticket
- [ ] Customer can add comments
- [ ] Customer CANNOT edit ticket properties
- [ ] Customer CANNOT close ticket

---

## Feature 4: Agent Creates Ticket for Customer

### 4.1 Create Ticket on Behalf of Customer

**Test Case:** Agent creates ticket for customer in different department

**Steps:**
1. Log in as `agent_sales` (Sales department)
2. Click "New Ticket"
3. Fill in form:
   - **Customer:** `customer1@test.com`
   - **Group:** Technical (different from agent's group)
   - **Subject:** "Customer needs technical support"
   - **Article:** "Customer called requesting help"
4. Click "Submit"

**Expected Results:**
- [ ] Ticket created successfully
- [ ] Ticket belongs to Technical group
- [ ] Customer is set as ticket customer
- [ ] Ticket appears in Technical group's overview
- [ ] Customer receives notification
- [ ] Agent (creator) can still access ticket
- [ ] History shows agent created it on behalf of customer

---

### 4.2 Permissions After Creation

**Test Case:** Verify creator maintains access

**Steps:**
1. As `agent_sales`, create ticket for Technical group
2. Verify ticket access
3. Try to edit ticket

**Expected Results:**
- [ ] Agent can view ticket (as creator)
- [ ] Agent can add comments
- [ ] Agent may have limited edit rights (depending on group settings)

---

## Feature 5: Custom Ticket Views

### 5.1 Create Custom Overview

**Test Case:** Create personal ticket overview

**Steps:**
1. Log in as `agent_sales`
2. Go to "Manage" → "Overviews"
3. Click "New Overview"
4. Configure:
   - **Name:** "My Urgent Tickets"
   - **Conditions:** 
     - State: Open
     - Priority: Urgent
     - Owner: Current user
   - **Sort by:** Priority (High to Low)
5. Click "Submit"

**Expected Results:**
- [ ] Overview created successfully
- [ ] Appears in sidebar navigation
- [ ] Shows only urgent tickets owned by agent
- [ ] Sorting works correctly
- [ ] Count badge shows correct number

---

### 5.2 Use Custom Filters

**Test Case:** Apply filters for shared tickets, approvals, CC

**Setup Custom Overview with:**
- [ ] **Filter:** "Tickets Shared with Me"
- [ ] **Filter:** "Tickets Pending My Approval"
- [ ] **Filter:** "Tickets I'm CC'd on"

**Steps:**
1. Create overview with "Shared with Me" filter
2. Check if shared tickets appear
3. Create overview with "Pending My Approval" filter
4. Verify approval requests show up

**Expected Results:**
- [ ] Custom filters work correctly
- [ ] Only matching tickets appear
- [ ] Counts are accurate
- [ ] Real-time updates work

---

## Feature 6: Grouped Overview Collapse/Expand

### 6.1 Collapse/Expand Groups

**Test Case:** Group tickets by priority and collapse

**Steps:**
1. Go to any overview
2. Enable grouping: "Group by Priority"
3. Observe grouped tickets (Urgent, High, Normal, Low)
4. Click on group header to collapse
5. Click again to expand

**Expected Results:**
- [ ] Tickets are grouped correctly
- [ ] Group headers show count
- [ ] Click collapses the group
- [ ] Arrow icon rotates (▼ to ▶)
- [ ] Tickets in group hide
- [ ] Click again expands
- [ ] State persists during session
- [ ] No JavaScript errors in console

---

### 6.2 Multiple Group Collapse

**Test Case:** Collapse multiple groups independently

**Steps:**
1. Group by State
2. Collapse "Open" group
3. Collapse "Pending" group
4. Expand "Open" group

**Expected Results:**
- [ ] Each group collapses independently
- [ ] No interference between groups
- [ ] UI remains responsive

---

## Cross-Feature Integration Tests

### 7.1 Approval + Share

**Test Case:** Share ticket that has approval request

**Steps:**
1. Create ticket with approval request
2. Share ticket with another group
3. Have shared group agent view ticket

**Expected Results:**
- [ ] Shared agent can see approval widget
- [ ] Shared agent CANNOT approve (only assigned approver can)
- [ ] Shared agent can read approval status

---

### 7.2 Approval + CC

**Test Case:** CC'd user sees approval

**Steps:**
1. Create ticket
2. Add CC user
3. Create approval request
4. Have CC user view ticket

**Expected Results:**
- [ ] CC'd user sees approval widget
- [ ] CC'd user CANNOT approve (unless they're the approver)
- [ ] CC'd user receives updates about approval actions

---

### 7.3 Share + CC

**Test Case:** Add CC to shared ticket

**Steps:**
1. Share ticket with group
2. Have shared group agent add CC

**Expected Results:**
- [ ] Shared agent can add CC (if they have permission)
- [ ] CC works normally
- [ ] No conflicts

---

### 7.4 All Three Features

**Test Case:** Ticket with approval, share, and CC

**Steps:**
1. Create ticket in Sales
2. Add CC: `agent_tech`
3. Request approval from `agent_support`
4. Share with Technical group

**Expected Results:**
- [ ] All three widgets show correct data
- [ ] No conflicts or errors
- [ ] All users receive appropriate notifications
- [ ] Permissions work correctly for each feature

---

## Notifications Testing

### 8.1 Online Notifications

**Test Case:** Real-time notifications appear

**Actions to Test:**
- [ ] Approval created
- [ ] Approval approved
- [ ] Approval rejected
- [ ] Approval updated
- [ ] Approval deleted
- [ ] Ticket shared
- [ ] Share updated
- [ ] Share revoked
- [ ] CC added
- [ ] CC removed

**Expected for Each:**
- [ ] Notification appears in bell icon
- [ ] Count increments
- [ ] Click opens related ticket
- [ ] Notification marked as read after viewing

---

### 8.2 Email Notifications

**Test Case:** Email notifications sent correctly

**For each action above, verify:**
- [ ] Email received within 1-2 minutes
- [ ] Subject line is descriptive
- [ ] Body contains relevant details
- [ ] Links work and open ticket
- [ ] Sender is correct
- [ ] No duplicate emails
- [ ] Unsubscribe link present (if applicable)

---

### 8.3 Notification Preferences

**Test Case:** Respect user notification settings

**Steps:**
1. User disables email notifications for "Approval"
2. Create approval request to that user

**Expected Results:**
- [ ] Online notification still appears
- [ ] Email is NOT sent
- [ ] Other notification types still work

---

## Permissions & Security Testing

### 9.1 Unauthorized Access

**Test Case:** Users cannot access without permission

**Steps:**
1. Create ticket in Sales group
2. Don't share, don't CC
3. Log in as `agent_tech` (Technical group)
4. Try to access ticket directly via URL

**Expected Results:**
- [ ] Access denied message
- [ ] Cannot view ticket details
- [ ] Cannot perform any actions

---

### 9.2 Customer Access

**Test Case:** Customers see only their tickets

**Steps:**
1. Log in as `customer1`
2. Check ticket overview

**Expected Results:**
- [ ] Only sees tickets where they are customer
- [ ] Only sees tickets where they are CC'd
- [ ] Cannot access admin features
- [ ] Cannot see other customers' tickets

---

### 9.3 Approval Permission

**Test Case:** Only approver can approve

**Steps:**
1. Create approval (A → B)
2. Log in as agent C
3. Try to approve via API or UI manipulation

**Expected Results:**
- [ ] Action blocked
- [ ] Error message shown
- [ ] Status unchanged

---

## UI/UX Testing

### 10.1 Responsive Design

**Test Case:** Features work on mobile

**Devices to Test:**
- [ ] Desktop (1920x1080)
- [ ] Tablet (768x1024)
- [ ] Mobile (375x667)

**Verify:**
- [ ] Widgets are accessible
- [ ] Buttons are clickable
- [ ] Forms are usable
- [ ] No horizontal scrolling
- [ ] Text is readable

---

### 10.2 Loading States

**Test Case:** Loading indicators appear

**Actions:**
- [ ] Creating approval
- [ ] Approving request
- [ ] Sharing ticket
- [ ] Adding CC

**Expected:**
- [ ] Loading spinner or indication
- [ ] Buttons disabled during action
- [ ] Success message after completion

---

### 10.3 Error Messages

**Test Case:** Clear error messages

**Trigger Errors:**
- [ ] Invalid approver selection
- [ ] Duplicate approval request
- [ ] Network error during action
- [ ] Invalid permissions

**Expected:**
- [ ] User-friendly error message
- [ ] No technical jargon
- [ ] Suggestions for resolution
- [ ] No application crash

---

## Performance & Error Handling

### 11.1 Large Data Sets

**Test Case:** Performance with many items

**Setup:**
- Create ticket with 10+ approvals
- Create ticket with 10+ shares
- Create ticket with 20+ CC users

**Expected Results:**
- [ ] UI remains responsive
- [ ] No lag when loading widgets
- [ ] Scrolling is smooth
- [ ] No browser freezing

---

### 11.2 Concurrent Actions

**Test Case:** Multiple users acting simultaneously

**Steps:**
1. Have 2 agents approve same approval at exact same time
2. Have 2 agents edit same approval simultaneously

**Expected Results:**
- [ ] No data corruption
- [ ] Proper error handling
- [ ] Last action wins (or proper conflict resolution)
- [ ] No exceptions in logs

---

### 11.3 Network Errors

**Test Case:** Handle network failures

**Steps:**
1. Start action (e.g., approve)
2. Disconnect network mid-request
3. Reconnect network

**Expected Results:**
- [ ] User notified of error
- [ ] Option to retry
- [ ] No partial/corrupt data
- [ ] State recovers gracefully

---

## Final Checklist

### Before Production Release

**Code Quality:**
- [ ] No console errors in browser
- [ ] No Ruby exceptions in logs
- [ ] All migrations run successfully
- [ ] Database schema is correct
- [ ] No TODO/FIXME comments in code

**Functionality:**
- [ ] All test cases pass
- [ ] No critical bugs found
- [ ] All features work as documented
- [ ] Rollback plan documented

**Documentation:**
- [ ] User guide updated
- [ ] Admin guide updated
- [ ] API documentation current
- [ ] Release notes prepared

**Performance:**
- [ ] Page load times acceptable (<2s)
- [ ] No memory leaks
- [ ] Database queries optimized
- [ ] WebSocket connections stable

**Security:**
- [ ] Permission checks in place
- [ ] SQL injection prevented
- [ ] XSS protection active
- [ ] CSRF tokens validated

---

## Bug Reporting Template

When bugs are found, report using this format:

**Bug Title:** Clear, descriptive title

**Severity:** Critical / High / Medium / Low

**Environment:** Test / Staging / Production

**Steps to Reproduce:**
1. Step 1
2. Step 2
3. Step 3

**Expected Result:** What should happen

**Actual Result:** What actually happened

**Screenshots:** Attach images

**Browser/Device:** Chrome 120 / Firefox / Safari / Mobile

**Console Errors:** Copy any error messages

**Additional Info:** Any other relevant details

---

## Sign-Off

**Tester Name:** ___________________  
**Date:** ___________________  
**Result:** ☐ Pass  ☐ Pass with Minor Issues  ☐ Fail  
**Comments:** ___________________

---

**End of Test Plan**

