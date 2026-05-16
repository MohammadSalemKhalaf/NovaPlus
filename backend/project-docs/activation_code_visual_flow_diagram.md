# Activation Code + Subscription Flow - Visual Diagram

## End-to-End User Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│             SALES AGENT ACTIVATION + SUBSCRIPTION FLOW              │
└─────────────────────────────────────────────────────────────────────┘

PHASE 1: CREATE ACTIVATION CODE
═════════════════════════════════════════════════════════════════════════

Screen: "Create Activation Code"
┌─────────────────────────────────────────────────────────────────┐
│ Duration Months: [1        ]                                     │
│                                                                  │
│ Code (Auto-generated):      ↻ (refresh)                         │
│ ┌────────────────────────────────────────┐ 📋 (copy)            │
│ │ ABC1XY9Z                               │                      │
│ └────────────────────────────────────────┘                      │
│                                                                  │
│ Note (optional): [          ]                                   │
│                                                                  │
│ sold_by_user_id: 5 (read-only)                                 │
│                                                                  │
│ ┌─────────────────────────────────────────┐                    │
│ │    [  Create Code  ] (or ⟲ if loading) │                    │
│ └─────────────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘

Action: User clicks "Create Code"
  ↓
API Request: POST /admin/subscriptions/codes
{
  "duration_months": 1,
  "sold_by_user_id": 5,
  "code": "ABC1XY9Z"              ← Only if !isEmpty
  "note": "..." (optional)         ← Only if !isEmpty
}
  ↓
Success Response: { "code": "ABC1XY9Z" }
  ↓
State Update: state.lastActivationCode = SalesAgentActivationCodeEntity(code: "ABC1XY9Z")
  ↓
Success Dialog:
┌─────────────────────────────────────────┐
│ ✓ Activation Code Created               │
│                                         │
│ Your activation code:                   │
│ ┌──────────────────────────┐ 📋       │
│ │  ABC1XY9Z                │ (copy)   │
│ └──────────────────────────┘           │
│                                         │
│ ℹ️  Share this code with the owner      │
│     to activate their subscription.     │
│                                         │
│           [ Done ]                      │
└─────────────────────────────────────────┘


PHASE 2: REDEEM SUBSCRIPTION (Smart Auto-Fill)
═════════════════════════════════════════════════════════════════════════

Screen: "Redeem Subscription"
Transition: User navigates to Subscriptions tab

PREFILL LOGIC TRIGGERED:
  if (state.lastActivationCode?.code != null) → Code field auto-fills
  if (state.lastOnboarding?.tenantId != null) → Tenant ID field auto-fills

Result:
┌─────────────────────────────────────────┐
│ ✅ Ready to activate subscription       │
│    for tenant 123                       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Activation Code (Auto-filled):                          │
│ ┌──────────────────────────┐                            │
│ │  ABC1XY9Z                │                            │
│ └──────────────────────────┘                            │
│                                                          │
│ Code (Edit if needed):                                  │
│ [ABC1XY9Z          ] (can be overwritten)              │
│                                                          │
│ Tenant ID: [123        ]                               │
│                                                          │
│ ┌──────────────────────────────────────┐               │
│ │  [  Activate Subscription  ]  (or ⟲) │               │
│ └──────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────┘

Action: User clicks "Activate Subscription"
  ↓
API Request: POST /admin/subscriptions/redeem
{
  "tenant_id": 123,
  "activation_code": "ABC1XY9Z"
}
  ↓
Success Response: { "status": "activated", ... }
  ↓
State Update: state.lastRedeemResult = SalesAgentRedeemResultEntity(...)
  ↓
Success Snackbar:
┌─────────────────────────────────────────────┐
│ ✅ Subscription redeemed successfully      │
└─────────────────────────────────────────────┘
```

---

## Data Flow Through Cubit State

```
ACTIVATION CREATION FLOW
════════════════════════════════════════════

User Forms → [Create Code Button]
    ↓
cubit.createActivationCode()
    ↓
SalesAgentRepository.createActivationCode()
    ↓
SalesAgentRemoteDataSource → POST /admin/subscriptions/codes
    ↓
Response { code: "ABC1XY9Z" }
    ↓
SalesAgentActivationCodeEntity(code: "ABC1XY9Z")
    ↓
state.copyWith(lastActivationCode: entity)
    ↓
_emit(newState)
    ↓
Consumer listens → UI updates with success dialog


REDEMPTION AUTO-FILL FLOW
════════════════════════════════════════════

User Navigates: Home → Subscriptions Tab
    ↓
RedeemSubscriptionScreen.initState()
    ↓
_prefillFields() checks:
    • state.lastActivationCode?.code ← Found: "ABC1XY9Z"
    • state.lastOnboarding?.tenantId ← Found: 123
    ↓
_code.text = "ABC1XY9Z"
_tenantId.text = "123"
    ↓
UI renders pre-filled form with green info banner
    ↓
User clicks "Activate Subscription"
    ↓
cubit.redeemSubscription(code: "ABC1XY9Z", tenantId: 123)
    ↓
SalesAgentRepository.redeemSubscription()
    ↓
SalesAgentRemoteDataSource → POST /admin/subscriptions/redeem
    ↓
Response { status: "activated", ... }
    ↓
SalesAgentRedeemResultEntity(status: "activated", ...)
    ↓
state.copyWith(lastRedeemResult: entity)
    ↓
_emit(newState)
    ↓
Consumer listens → UI updates with success snackbar
```

---

## Request/Response Diagram

```
REQUEST BODY CLEANING
═════════════════════════════════════════════

BEFORE SUBMISSION:

_code.text = "ABC1XY9Z"
_note.text = "" (empty)

CLEANING LOGIC:

const codeValue = _code.text.trim() = "ABC1XY9Z"
const noteValue = _note.text.trim() = ""

Build body:
{
  "duration_months": 1,
  "sold_by_user_id": 5
}

if (codeValue.isNotEmpty) → YES  → body["code"] = "ABC1XY9Z"
if (noteValue.isNotEmpty) → NO   → skip (no empty string!)

FINAL BODY SENT:

{
  "duration_months": 1,
  "sold_by_user_id": 5,
  "code": "ABC1XY9Z"
}

✅ No empty strings! No 422 errors!
```

---

## Copy-to-Clipboard Flow

```
USER INITIATES COPY
═════════════════════════════════════════

Location 1: Activation Creation Screen
  [ABC1XY9Z] 📋 ← User taps copy icon
       ↓
  Clipboard.setData(ClipboardData(text: "ABC1XY9Z"))
       ↓
  Toast: "Code copied to clipboard" (2 seconds, green)
       ↓
  Code now in system clipboard


Location 2: Success Dialog
  ┌──────────────────────┐
  │  ABC1XY9Z      📋    │  ← User taps copy icon
  └──────────────────────┘
       ↓
  Clipboard.setData(ClipboardData(text: "ABC1XY9Z"))
       ↓
  Toast: "Code copied to clipboard"


Location 3: Redeem Screen (If manually shown)
  Code (Auto-filled):
  [ABC1XY9Z] 📋  ← User can copy again if needed
       ↓
  Clipboard.setData(ClipboardData(text: "ABC1XY9Z"))
       ↓
  Toast: "Code copied to clipboard"


PASTE ANYWHERE
═════════════════════════════════════════

User can now:
  • Paste to email
  • Paste to message
  • Send via WhatsApp
  • Save to notes
  • Share with owner
```

---

## Loading State Diagram

```
BUTTON STATE MACHINE
═════════════════════════════════════════

IDLE STATE: state.submitting = false
  ┌──────────────────────┐
  │  Create Code         │  ← Enabled, clickable
  └──────────────────────┘

User clicks
     ↓

SUBMITTING STATE: state.submitting = true
  ┌──────────────────────┐
  │       ⟲ (spinner)    │  ← Disabled, spinning
  └──────────────────────┘

API response arrives
     ↓

SUCCESS: state.lastActivationCode != null
  └─→ Show success dialog

ERROR: state.errorMessage != null
  └─→ Show red snackbar

Back to IDLE STATE: state.submitting = false
  ┌──────────────────────┐
  │  Create Code         │  ← Enabled again
  └──────────────────────┘
```

---

## Validation Flow

```
USER INPUT → VALIDATION → SUBMISSION
═════════════════════════════════════════

Duration Months Field:
  Input: "0"
  Validation: int.tryParse("0") = 0 (not > 0)
  Result: Red error "Duration must be a positive number"
  Submit: ❌ BLOCKED

Duration Months Field:
  Input: "12"
  Validation: int.tryParse("12") = 12 (✓ > 0)
  Result: ✅ PASS

Tenant ID Field:
  Input: "abc"
  Validation: int.tryParse("abc") = null
  Result: Red error "Tenant ID must be a positive number"
  Submit: ❌ BLOCKED

Tenant ID Field:
  Input: "123"
  Validation: int.tryParse("123") = 123 (✓ > 0)
  Result: ✅ PASS

Code Field:
  Input: "" (empty)
  Condition: required = false
  Result: ✅ PASS (optional field)

All Fields Valid
  Submit: ✅ ALLOWED
```

---

## Smart Prefill Decision Diagram

```
REDEEM SCREEN INITIALIZATION
═════════════════════════════════════════

didChangeDependencies() triggered
     ↓
Call: _prefillFields()
     ↓

Check 1: state.lastActivationCode?.code
  ├─ NULL → Code field empty (manual entry required)
  └─ "ABC1XY9Z" → Code field = "ABC1XY9Z"
       ↓
    Show green info: "Code auto-filled from generated code"

Check 2: state.lastOnboarding?.tenantId
  ├─ NULL → Tenant ID field empty (manual entry required)
  └─ 123 → Tenant ID field = "123"
       ↓
    Show green info: "Tenant ID auto-filled from onboarding"

Both Checks Result:
  ├─ Both NULL → Info banner hidden
  │             Button: "Redeem Code"
  │             
  ├─ Code only → Info: "Code auto-filled from generated code"
  │             Button: "Redeem Code"
  │             
  ├─ Tenant only → Info: "Tenant ID auto-filled from onboarding"
  │               Button: "Redeem Code"
  │               
  └─ Both filled → Info: "Ready to activate subscription for tenant 123"
                  Button: "Activate Subscription" 🟢
```

---

## Summary: How Data Flows Without Manual Entry

```
┌─────────────────────┐
│  Onboarding Owner   │
│  (Previous Step)    │
│  Result: tenant_id  │
└──────────┬──────────┘
           │
           ↓
    [Stored in State]
  state.lastOnboarding
  {
    ownerUserId: ...,
    tenantId: 123,      ← Saved here
    email: ...
  }
           │
           ↓
┌─────────────────────────────────────┐
│  Create Activation Code             │
│  - Code auto-generated (ABC1XY9Z)   │
│  - Stored in state                  │
│    state.lastActivationCode:        │
│    { code: "ABC1XY9Z" }             │
└──────────┬────────────┬─────────────┘
           │            │
           ↓            ↓
    ┌──────────────────────────────┐
    │ Redeem Subscription Screen    │
    │                              │
    │ Code auto-filled: ABC1XY9Z  │  ← From state.lastActivationCode
    │ Tenant ID auto-filled: 123  │  ← From state.lastOnboarding
    │                              │
    │ Green banner:                │
    │ "Ready to activate..."       │
    │                              │
    │ [Activate Subscription] 🟢   │  ← Button ready to go
    └──────────┬───────────────────┘
               │
               ↓
         API Submit
         POST /admin/subscriptions/redeem
         {
           "tenant_id": 123,
           "activation_code": "ABC1XY9Z"
         }
               │
               ↓
         ✅ Subscription Activated!
```

---

## Benefits Summary

| Aspect | Traditional | With This Flow |
|--------|------------|-----------------|
| **Code Entry** | User types manually | Auto-generated + copy button |
| **Tenant ID Entry** | User types ID | Auto-filled from onboarding |
| **Error Rate** | High (typos) | None (auto-generated) |
| **Data Reuse** | Manual re-entry each time | Automatic from state |
| **Copy Effort** | Write down & transcribe | One-click copy |
| **Request Validation** | Send empty strings → 422 errors | Clean request, no empties |
| **User Experience** | 5+ separate manual entries | Click "Activate" button |

---

## Files Involved

```
lib/features/sales_agent/
├── presentation/
│   ├── screens/
│   │   ├── sales_agent_activation_code_screen.dart     ✅ MODIFIED
│   │   ├── sales_agent_redeem_subscription_screen.dart ✅ MODIFIED
│   │   └── ...
│   └── cubit_or_bloc/
│       └── sales_agent_cubit.dart                      (state already ready)
│
├── data/
│   ├── datasources/
│   │   └── sales_agent_remote_data_source.dart         (endpoints ready)
│   ├── models/
│   ├── repositories/
│   │   └── sales_agent_repository_impl.dart            (logic ready)
│   └── ...
│
└── domain/
    ├── entities/
    │   ├── sales_agent_activation_code_entity.dart     (already complete)
    │   ├── sales_agent_redeem_result_entity.dart       (already complete)
    │   └── ...
    └── repositories/
        └── sales_agent_repository.dart                 (contract ready)
```
