# Zammad Custom Features - Testing Plan & Checklist

**Version:** 1.0  
**Date:** November 2025  
**Test Environment:** Production-like staging environment  
**Testers:** QA Team 

---

## 📋 Table of Contents
1. [Test Environment Setup](#test-environment-setup)
2. [Feature 1: Ticket Approval System](#feature-1-ticket-approval-system)
3. [Feature 2: Ticket Sharing System](#feature-2-ticket-sharing-system)
4. [Feature 3: CC (Carbon Copy) System](#feature-3-cc-carbon-copy-system)
5. [Feature 4: Trigger-Based Share and Approval Creation](#feature-4-trigger-based-share-and-approval-creation)
6. [Feature 5: Agent Creates Ticket for Customer](#feature-5-agent-creates-ticket-for-customer)
7. [Feature 6: Custom Ticket Views](#feature-6-custom-ticket-views)
8. [Feature 7: Grouped Overview Collapse/Expand](#feature-7-grouped-overview-collapseexpand)
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
- [ ] **Group A** - Primary department (e.g., Sales)
- [ ] **Group B** - Secondary department (e.g., Support)  
- [ ] **Group C** - Third department (e.g., Technical)

### Required Test Users
- [ ] **Admin** - Full system access
- [ ] **Agent A** - Agent in Group A
- [ ] **Agent B** - Agent in Group B
- [ ] **Agent C** - Agent in Group C
- [ ] **Customer 1** - Primary customer account
- [ ] **Customer 2** - Secondary customer account

**Note:** Throughout this test plan:
- **Requester** = User who creates approval/share
- **Approver/Receiver** = User who receives approval/share
- **Sender** = User who initiates action
- **Agent A/B/C** = Agents from different groups

---

## Feature 1: Ticket Approval System

### 1.1 Create Approval Request

**Test Case:** Agent requests approval from another agent

**Steps:**
1. Log in as **Requester** (Agent A from Group A)
2. Open any ticket in Group A
3. Click on "Approvals" widget in the right sidebar
4. Click "Request Approval" button
5. Fill in the approval form:
   - **Approver:** Select **Approver** (Agent B from Group B)
   - **Message:** "Please approve this customer discount request"
   - **Priority:** Select "High"
6. Click "Request Approval"

**Expected Results:**
- [ ] Approval request appears in the sidebar immediately
- [ ] Status shows "Pending"
- [ ] Priority badge shows "High" in red/orange
- [ ] Online notification appears for **Approver**
- [ ] Email notification sent to **Approver**
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
1. Log in as **Approver** (Agent B)
2. Check online notifications (bell icon)
3. Click on the approval notification
4. Navigate to the ticket
5. Open "Approvals" widget

**Expected Results:**
- [ ] Approval card is displayed
- [ ] Shows "Request from [Requester name]"
- [ ] Message is visible
- [ ] Priority is shown
- [ ] "Approve" and "Reject" buttons are visible
- [ ] No "Edit" or "Delete" buttons (requester only)
- [ ] Ticket is accessible (approver has permission to view)

---

### 1.3 Approve Request

**Test Case:** Approver approves the request

**Steps:**
1. As **Approver**, click "Approve" button
2. Confirm the action if prompted

**Expected Results:**
- [ ] Status changes to "Approved" immediately
- [ ] Status badge turns green
- [ ] Approve/Reject buttons disappear
- [ ] Online notification sent to **Requester**
- [ ] Email notification sent to **Requester**
- [ ] Email subject includes "Approved"
- [ ] History entry added to ticket
- [ ] Real-time update on requester's screen (if they have ticket open)

---

### 1.4 Reject Request

**Test Case:** Approver rejects the request

**Setup:**
1. Create another approval request (Agent A → Agent C)

**Steps:**
1. Log in as **Approver** (Agent C)
2. Open the ticket with pending approval
3. Click "Reject" button

**Expected Results:**
- [ ] Status changes to "Rejected" immediately
- [ ] Status badge turns red
- [ ] Approve/Reject buttons disappear
- [ ] Online notification sent to **Requester**
- [ ] Email notification sent to **Requester**
- [ ] Email subject includes "Rejected"
- [ ] History entry added to ticket

---

### 1.5 Edit Approval Request (Pending Only)

**Test Case:** Requester can edit their pending request

**Setup:**
1. Create a new approval request (Agent A → Agent B)

**Steps:**
1. As **Requester**, open the ticket
2. In Approvals widget, click "Edit" button
3. Change message to "Updated: Please review urgently"
4. Change priority to "Urgent"
5. Click "Update"

**Expected Results:**
- [ ] Message updates immediately
- [ ] Priority badge changes to "Urgent"
- [ ] Online notification sent to **Approver** about update
- [ ] Email sent to **Approver**
- [ ] History entry shows "Approval request updated"

---

### 1.6 Delete Approval Request

**Test Case:** Requester can delete PENDING approval, but NOT approved/rejected

**Part A: Delete Pending Approval**

**Steps:**
1. Create approval request (Agent A → Agent B)
2. As **Requester**, click "Delete" button
3. Confirm deletion

**Expected Results:**
- [ ] Approval card disappears immediately
- [ ] Confirmation modal shows before deletion
- [ ] Online notification sent to **Approver**
- [ ] Email sent to **Approver** about cancellation
- [ ] History entry added

**Part B: Cannot Delete Approved/Rejected** ⚠️ **CRITICAL**

**Steps:**
1. Create approval and have it approved by **Approver**
2. As **Requester**, check the Approvals widget

**Expected Results:**
- [ ] **Delete button is HIDDEN** for approved requests
- [ ] **Delete button is HIDDEN** for rejected requests
- [ ] Only pending requests show Edit/Delete buttons

---

### 1.7 Permissions Testing

**Test Case:** Only authorized users can approve

**Steps:**
1. Create approval (Agent A → Agent B)
2. Log in as Agent C (NOT the approver)
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
1. As **Requester** (Agent A), create approval request to Agent B
2. Create another approval request to Agent C

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
1. Log in as **Sender** (Agent from Group A)
2. Create or open a ticket in Group A
3. Click on "Share" widget in sidebar
4. Click "Share Ticket" button
5. Select Group B (target department)
6. Add optional message: "Please assist with technical details"
7. Click "Share"

**Expected Results:**
- [ ] Share appears in the sidebar immediately
- [ ] Shows shared group name
- [ ] Shows "Shared by [Sender name]"
- [ ] Status shows "Active"
- [ ] Online notifications sent to all agents in Group B
- [ ] Email notifications sent to all agents in Group B
- [ ] Shared ticket appears in Group B's ticket list

---

### 2.2 Shared Ticket Access (Receiver)

**Test Case:** Agents in shared group can access ticket

**Steps:**
1. Log in as **Receiver** (Agent from Group B)
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
1. Create ticket in Group A (owner: Group A)
2. Share with Group A
3. Have another agent from Group A access it

**Expected Results:**
- [ ] Full access (read, comment, edit, close)

**Scenario B: Receiver from DIFFERENT group**

**Steps:**
1. Create ticket in Group A
2. Share with Group B  
3. Have agent from Group B access it

**Expected Results:**
- [ ] Read access: ✅
- [ ] Comment access: ✅
- [ ] Edit/Close access: ❌ (comment-only)

---

### 2.4 Update/Edit Share

**Test Case:** Share creator can edit share details

**Steps:**
1. As **Sender**, open a ticket with active share
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
1. As **Sender**, click "Revoke" on active share
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
1. Share ticket with Group B
2. Share same ticket with Group C

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
1. Log in as **Agent A**
2. Click "New Ticket"
3. Fill in ticket details:
   - Customer: **Customer 1**
   - Group: Group A
   - Subject: "Test CC functionality"
4. In CC field, add:
   - Agent B
   - Agent C
5. Click "Submit"

**Expected Results:**
- [ ] Ticket created successfully
- [ ] CC widget shows both CC'd users
- [ ] Each CC user receives online notification
- [ ] Each CC user receives email notification
- [ ] CC'd users can see ticket in their overview
- [ ] History shows "CC added" entries

---

### 3.2 CC User Access & Permissions

**Test Case:** Verify CC users have appropriate access

**Steps:**
1. Create ticket in Group A
2. CC **Agent B** (from Group B)
3. Log in as **Agent B**
4. Find and open the ticket

**Expected Results:**
- [ ] Ticket is visible in overview
- [ ] Can read all ticket details
- [ ] **Permissions based on user's group access to ticket's group:**
  - **Agent with full access to Group A:** Can read, comment, and edit ticket
  - **Agent with read access to Group A:** Can read and comment only
  - **Agent with no access to Group A:** Can read and comment only (CC access)
  - **Customer:** Read + comment only

**Note:** CC does NOT automatically grant full access. Agent permissions are determined by their group membership and access level to the ticket's group.

---

### 3.3 CC with Customer Role

**Test Case:** Add customer as CC

**Steps:**
1. Create ticket
2. Add **Customer 2** as CC

**Expected Results:**
- [ ] Customer appears in CC list
- [ ] Customer receives notification
- [ ] Customer can view ticket
- [ ] Customer can add comments
- [ ] Customer CANNOT edit ticket properties
- [ ] Customer CANNOT close ticket

---

---

## Feature 4: Trigger-Based Share and Approval Creation

### 4.1 Create Share via Trigger

**Test Case:** Automatically share ticket with group via trigger

**Prerequisites:**
- Create a trigger with condition and action to share ticket
  - **Condition:** e.g., "Priority is High" and "Group is Group A"
  - **Action:** "Share with Group" → Select Group B

**Steps:**
1. Create or update a ticket matching trigger conditions
   - Set Priority to "High"
   - Set Group to Group A
2. Submit the ticket

**Expected Results:**
- [ ] Trigger executes automatically
- [ ] Ticket is automatically shared with Group B
- [ ] Share appears in Share widget
- [ ] Status shows "Active"
- [ ] Online notifications sent to Group B agents
- [ ] Email notifications sent to Group B agents
- [ ] History entry shows "Shared via trigger"
- [ ] Shared group agents can access ticket

---

### 4.2 Create Approval via Trigger

**Test Case:** Automatically create approval request via trigger

**Prerequisites:**
- Create a trigger with condition and action to request approval
  - **Condition:** e.g., "State is Open" and "Priority is Urgent"
  - **Action:** "Request Approval" → Select **Agent B** as approver

**Steps:**
1. Create or update a ticket matching trigger conditions
   - Set State to "Open"
   - Set Priority to "Urgent"
2. Submit the ticket

**Expected Results:**
- [ ] Trigger executes automatically
- [ ] Approval request is automatically created
- [ ] Approval appears in Approvals widget
- [ ] Status shows "Pending"
- [ ] Approver (Agent B) receives online notification
- [ ] Approver (Agent B) receives email notification
- [ ] History entry shows "Approval requested via trigger"
- [ ] Approver can approve/reject normally

---

### 4.3 Multiple Shares via Trigger

**Test Case:** Share with multiple groups via trigger

**Prerequisites:**
- Create trigger that shares with multiple groups
  - **Condition:** "Group is Group A"
  - **Action:** "Share with Group" → Select Group B AND Group C

**Steps:**
1. Create ticket in Group A matching trigger conditions
2. Submit the ticket

**Expected Results:**
- [ ] Ticket shared with both Group B and Group C
- [ ] Both share cards appear in Share widget
- [ ] Each share is independent
- [ ] All agents from both groups receive notifications
- [ ] All agents from both groups can access ticket

---

### 4.4 Trigger Share + Manual Approval

**Test Case:** Combine trigger-based share with manual approval

**Steps:**
1. Create ticket that triggers auto-share with Group B
2. Manually create approval request to Agent C

**Expected Results:**
- [ ] Automatic share works via trigger
- [ ] Manual approval works normally
- [ ] Both features coexist without conflicts
- [ ] All notifications sent correctly

---

## Feature 5: Agent Creates Ticket for Another Department (Self as Customer)

### 5.1 Create Ticket for Different Department

**Test Case:** Agent creates ticket for different department and adds themselves as customer

**Steps:**
1. Log in as **Agent A** (from Group A)
2. Click "New Ticket"
3. Fill in form:
   - **Customer:** **Agent A** (themselves)
   - **Group:** Group C (different from agent's own group)
   - **Subject:** "Need technical support from another department"
   - **Article:** "I need assistance from the technical team"
4. Click "Submit"

**Expected Results:**
- [ ] Ticket created successfully
- [ ] Ticket belongs to Group C (target department)
- [ ] **Agent A is set as the customer** on the ticket
- [ ] Ticket appears in Group C's overview
- [ ] Agent A can still access the ticket (as customer)
- [ ] History shows Agent A created the ticket

---

### 5.2 Access and Permissions as Customer

**Test Case:** Verify agent maintains access when listed as customer

**Steps:**
1. As **Agent A**, after creating ticket for Group C (with self as customer)
2. Navigate away and return to ticket list
3. Find and open the ticket
4. Try to add comment/article
5. Try to edit ticket properties

**Expected Results:**
- [ ] Agent A can view the ticket (listed as customer)
- [ ] Agent A can add comments/articles
- [ ] Agent A can see all ticket activity
- [ ] Agent A has customer-level permissions (not full agent permissions for Group C)
- [ ] Agent A CANNOT change ticket owner or close ticket (unless they have Group C access)
- [ ] Ticket remains visible in their overview

---

## Feature 6: Custom Ticket Views

### 6.1 Create Custom Overview

**Test Case:** Create personal ticket overview

**Steps:**
1. Log in as **Agent A**
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

### 6.2 Use Custom Filters

**Test Case:** Apply filters for shared tickets and approvals

**Setup Custom Overview with:**
- [ ] **Filter:** "Tickets Shared with Me"
- [ ] **Filter:** "Tickets Pending My Approval"

**Steps:**
1. Create overview with "Shared with Me" filter
2. Check if shared tickets appear
3. Verify count badge shows correct number
4. Create overview with "Pending My Approval" filter
5. Verify approval requests show up
6. Verify count badge shows correct number

**Expected Results:**
- [ ] Custom filters work correctly
- [ ] Only matching tickets appear
- [ ] Counts are accurate
- [ ] Real-time updates work
- [ ] Filters can be combined with other conditions (e.g., State, Priority)

---

## Feature 7: Grouped Overview Collapse/Expand

### 7.1 Collapse/Expand Groups

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

### 7.2 Multiple Group Collapse

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

### 8.1 Approval + Share

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

### 8.2 Approval + CC

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

### 8.3 Share + CC

**Test Case:** Add CC to shared ticket

**Steps:**
1. Share ticket with group
2. Have shared group agent add CC

**Expected Results:**
- [ ] Shared agent can add CC (if they have permission)
- [ ] CC works normally
- [ ] No conflicts

---

### 8.4 All Three Features

**Test Case:** Ticket with approval, share, and CC

**Steps:**
1. Create ticket in Group A
2. Add CC: **Agent C**
3. Request approval from **Agent B**
4. Share with Group C

**Expected Results:**
- [ ] All three widgets show correct data
- [ ] No conflicts or errors
- [ ] All users receive appropriate notifications
- [ ] Permissions work correctly for each feature

---

## Notifications Testing

### 9.1 Online Notifications

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

### 9.2 Email Notifications

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

### 9.3 Notification Preferences

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

### 10.1 Unauthorized Access

**Test Case:** Users cannot access without permission

**Steps:**
1. Create ticket in Group A
2. Don't share, don't CC
3. Log in as **Agent C** (from Group C)
4. Try to access ticket directly via URL

**Expected Results:**
- [ ] Access denied message
- [ ] Cannot view ticket details
- [ ] Cannot perform any actions

---

### 10.2 Customer Access

**Test Case:** Customers see only their tickets

**Steps:**
1. Log in as **Customer 1**
2. Check ticket overview

**Expected Results:**
- [ ] Only sees tickets where they are customer
- [ ] Only sees tickets where they are CC'd
- [ ] Cannot access admin features
- [ ] Cannot see other customers' tickets

---

### 10.3 Approval Permission

**Test Case:** Only approver can approve

**Steps:**
1. Create approval (Agent A → Agent B)
2. Log in as Agent C
3. Try to approve via API or UI manipulation

**Expected Results:**
- [ ] Action blocked
- [ ] Error message shown
- [ ] Status unchanged

---

## UI/UX Testing

### 11.1 Loading States

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

### 11.2 Error Messages

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

### 12.1 Large Data Sets

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

### 12.2 Concurrent Actions

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

### 12.3 Network Errors

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

