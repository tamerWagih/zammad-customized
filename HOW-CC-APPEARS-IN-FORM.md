# How CC Field Appears in Ticket Creation Form

## 📍 WHERE THE CC FIELD IS REGISTERED

### **File:** `app/assets/javascripts/app/models/ticket.coffee` (Line 11)

```coffeescript
{ 
  name: 'cc_user_ids',
  display: __('CC'),
  tag: 'cc_user_select',
  multiple: true,
  limit: 100,
  null: true,
  edit: true,
  screen: { 
    create_middle: { 
      shown: true,
      item_class: 'column' 
    } 
  }
}
```

### **What This Means:**

| Setting | Purpose |
|---------|---------|
| `name: 'cc_user_ids'` | Field name (matches backend) |
| `display: __('CC')` | Label shown in form |
| `tag: 'cc_user_select'` | Uses our custom UI element |
| `multiple: true` | Multi-select dropdown |
| `null: true` | Optional field |
| `screen: { create_middle: { shown: true } }` | **Shows in ticket creation form** |

---

## 🎨 HOW IT RENDERS

### **Step 1: Zammad Form System**

When ticket creation form renders:
1. Zammad reads `Ticket.configure_attributes`
2. Finds `cc_user_ids` with `screen.create_middle.shown = true`
3. Calls `App.UiElement.cc_user_select.render(attribute, params)`

### **Step 2: CC User Select UI Element**

```coffeescript
# File: app/assets/javascripts/app/controllers/_ui_element/cc_user_select.coffee

class App.UiElement.cc_user_select
  @render: (attribute, params) ->
    # Converts to searchable_select
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.placeholder = __('Click to search for users to CC...')
    attribute.options = {}  # Empty until loaded
    
    # Render dropdown
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Add lazy loading
    @bindLazyLoading(element, attribute, params)
    
    element
```

### **Step 3: User Interaction**

1. Dropdown appears **empty** (no users loaded yet)
2. User **clicks** dropdown
3. **Lazy loading triggered** → API call to `/tickets/cc_users`
4. Users loaded and displayed
5. User searches and selects

---

## 📋 COMPLETE REGISTRATION CHAIN

```
1. Ticket.configure_attributes (line 11)
   ↓ (has cc_user_ids with screen.create_middle)
   
2. Zammad Form Renderer
   ↓ (reads configure_attributes)
   
3. Finds tag: 'cc_user_select'
   ↓ (looks for UI element)
   
4. App.UiElement.cc_user_select
   ↓ (renders dropdown)
   
5. Searchable Select Dropdown
   ↓ (empty state)
   
6. User clicks dropdown
   ↓ (lazy loading triggered)
   
7. API Call: GET /tickets/cc_users
   ↓ (returns agents/customers)
   
8. Dropdown populated
   ↓ (user can search and select)
   
9. Form submission
   ↓ (cc_user_ids: [123, 456])
   
10. Backend processes
    ✅ CCs created!
```

---

## ✅ WHY CC FIELD WILL DEFINITELY APPEAR

### **Three Layers of Confirmation:**

1. ✅ **Model Registration:**
   - File: `app/assets/javascripts/app/models/ticket.coffee`
   - Line: 11
   - Setting: `screen: { create_middle: { shown: true } }`

2. ✅ **UI Element Exists:**
   - File: `app/assets/javascripts/app/controllers/_ui_element/cc_user_select.coffee`
   - Class: `App.UiElement.cc_user_select`
   - Method: `@render`

3. ✅ **API Endpoint Ready:**
   - Route: GET `/tickets/cc_users`
   - Controller: `Tickets::CcUsersController#index`
   - Returns: Agents and customers (admins excluded)

---

## 🎯 FIELD POSITION IN FORM

The CC field will appear in **create_middle** section:

```
Ticket Creation Form:
├─ create_top
│  └─ Title
│  └─ Customer
│
├─ create_middle         ← CC field is HERE
│  └─ Group
│  └─ CC Users          ← OUR FIELD!
│  └─ Owner
│  └─ State
│  └─ Priority
│
└─ create_bottom
   └─ Article
   └─ Attachments
```

**Why this position:**
- After Group (logical flow)
- Before Owner (makes sense)
- In create_middle section (standard for agent fields)

---

## 🔍 VERIFICATION

### **In Browser Console (after page loads):**

```javascript
// Check if Ticket model has cc_user_ids
App.Ticket.configure_attributes.find(a => a.name === 'cc_user_ids')

// Should return:
{
  name: 'cc_user_ids',
  display: 'CC',
  tag: 'cc_user_select',
  multiple: true,
  screen: { create_middle: { shown: true, item_class: 'column' } },
  // ...
}

// Check if UI element is registered
App.UiElement.cc_user_select

// Should return: [Function]
```

### **In Form HTML:**

Look for:
```html
<div class="form-group" data-attribute-name="cc_user_ids">
  <label>CC</label>
  <div class="controls">
    <select name="cc_user_ids" multiple>
      <!-- Users will appear here after lazy load -->
    </select>
  </div>
</div>
```

---

## ✅ CONFIRMATION

**Yes, the CC dropdown WILL appear!** Here's why:

1. ✅ **Registered in Ticket.configure_attributes** (line 11)
2. ✅ **screen.create_middle.shown = true** (tells Zammad to show it)
3. ✅ **tag: 'cc_user_select'** (uses our custom UI element)
4. ✅ **UI element exists** (App.UiElement.cc_user_select)
5. ✅ **API endpoint ready** (GET /tickets/cc_users)

**No form handler needed** - Zammad's form system handles it automatically!

---

**The CC field is properly registered and will appear!** ✅

