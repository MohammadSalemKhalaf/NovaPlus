# API_CONTRACTS_PHASE_1.md

## 1. Purpose

This document defines the Phase 1 API contract direction for the AI Commerce Platform.

The API layer must support:
- merchant/admin operations
- public customer-facing experiences
- internal/external webhook handling
- future-safe extension without breaking core flows

Phase 1 APIs must be explicit, tenant-safe, validation-heavy, and production-ready.

---

## 2. API Design Principles

### 2.1 Separation of Concerns
The API surface must be clearly separated into:
- Admin APIs
- Public APIs
- Webhook/Internal APIs

### 2.2 Tenant Safety
- Authenticated admin APIs must always resolve tenant access from the authenticated membership context.
- Public APIs must only expose tenant-public data.
- Webhook APIs must validate provider authenticity before processing.

### 2.3 Money Safety
Any endpoint that reads or writes money-related values must use deterministic system fields only.

### 2.4 Stable Contracts
Prefer explicit contracts over overly dynamic payloads.

### 2.5 Versioning Strategy
Phase 1 should start with a versioned API namespace.

Recommended base path:
- `/api/v1/admin/...`
- `/api/v1/public/...`
- `/api/v1/webhooks/...`

---

## 3. Authentication and Authorization Direction

## 3.1 Admin APIs
Admin APIs require:
- authenticated user
- valid tenant membership
- role-based permission checks

### Recommended pattern
- Authentication token/session identifies user
- Active tenant resolved via:
  - explicit tenant header validated against membership, or
  - tenant context in route for selected endpoints, or
  - server-managed active workspace context

### Rule
Never trust raw client-supplied tenant identifiers without verifying membership.

---

## 3.2 Public APIs
Public APIs:
- require no authentication
- must expose only public, published, tenant-scoped data
- must never expose internal-only status, audit, or admin records

---

## 3.3 Webhook APIs
Webhook endpoints must:
- validate provider signature/token
- persist raw payload before deep processing when appropriate
- return fast acknowledgment
- dispatch async work for heavy processing

---

## 4. Response Envelope Convention

Recommended response direction for JSON APIs:

### Success
```json
{
  "success": true,
  "message": "Resource fetched successfully.",
  "data": {},
  "meta": {}
}
```

### Error
```json
{
  "success": false,
  "message": "Validation failed.",
  "errors": {
    "field_name": ["The field is required."]
  }
}
```

### Notes
- Keep messages human-readable.
- Use `meta` for pagination or lightweight response metadata.
- Avoid hiding business-critical information in unstructured strings.

---

## 5. Admin API Groups

## 5.1 Auth / Session

### POST `/api/v1/admin/auth/login`
Authenticates a merchant user.

#### Request
```json
{
  "email": "merchant@example.com",
  "password": "secret-password"
}
```

#### Response
```json
{
  "success": true,
  "message": "Login successful.",
  "data": {
    "token": "jwt-or-access-token",
    "user": {
      "id": 1,
      "name": "John Doe",
      "email": "merchant@example.com"
    },
    "tenants": [
      {
        "id": 10,
        "name": "Fresh Market",
        "slug": "fresh-market",
        "role": "owner"
      }
    ]
  }
}
```

---

### POST `/api/v1/admin/auth/logout`
Invalidates current session/token.

---

### GET `/api/v1/admin/auth/me`
Returns authenticated user and accessible tenant memberships.

---

## 5.2 Tenant / Workspace Setup

### POST `/api/v1/admin/tenants`
Creates a new tenant/workspace.

#### Request
```json
{
  "name": "Fresh Market",
  "slug": "fresh-market",
  "business_mode": "product",
  "primary_language": "en",
  "currency_code": "USD",
  "timezone": "Asia/Hebron"
}
```

#### Validation
- name required
- slug required and globally unique
- business_mode in `product`, `service`
- currency_code required
- timezone required

#### Response
Returns created tenant and membership context.

---

### GET `/api/v1/admin/tenants/current`
Returns current active tenant context.

---

### PATCH `/api/v1/admin/tenants/current`
Updates tenant-level workspace settings.

#### Allowed fields
- name
- primary_language
- currency_code
- timezone
- status (restricted by privileged roles only if used)

---

## 5.3 Business Profile

### GET `/api/v1/admin/business-profile`
Returns current tenant business profile.

---

### PUT `/api/v1/admin/business-profile`
Creates or updates business profile.

#### Request
```json
{
  "business_name": "Fresh Market",
  "short_about": "Neighborhood grocery store.",
  "phone_number": "+970...",
  "whatsapp_number": "+970...",
  "address_text": "Nablus, Palestine",
  "public_visibility": "public"
}
```

#### Notes
- Logo and cover image should be handled via upload endpoints or upload references.

---

## 5.4 Public Page Settings

### GET `/api/v1/admin/public-page-settings`
Returns settings for public page behavior.

---

### PUT `/api/v1/admin/public-page-settings`
Updates public page settings.

#### Request
```json
{
  "homepage_mode": "catalog",
  "is_published": true,
  "primary_cta_type": "whatsapp",
  "primary_cta_payload": null
}
```

#### Validation
- homepage_mode in `catalog`, `services`, `landing`
- primary_cta_type in `whatsapp`, `catalog`, `services`

---

## 5.5 Categories

### GET `/api/v1/admin/categories`
Returns tenant categories.

#### Query params
- search
- status
- page
- per_page

---

### POST `/api/v1/admin/categories`
Creates a category.

#### Request
```json
{
  "name": "Beverages",
  "slug": "beverages",
  "description": "Drinks and juices",
  "parent_id": null,
  "sort_order": 1,
  "status": "active"
}
```

#### Validation
- name required
- slug required and unique within tenant
- parent_id nullable but must belong to same tenant if provided

---

### GET `/api/v1/admin/categories/{id}`
Returns single category.

---

### PUT `/api/v1/admin/categories/{id}`
Updates category.

---

### DELETE `/api/v1/admin/categories/{id}`
Archives or soft-deletes category depending on policy.

#### Rule
Do not hard-delete if linked items exist unless an explicit safe policy is implemented.

---

## 5.6 Products / Items

### GET `/api/v1/admin/items`
Returns tenant products/items.

#### Query params
- search
- category_id
- status
- visibility
- page
- per_page
- sort

---

### POST `/api/v1/admin/items`
Creates a product/item.

#### Request
```json
{
  "category_id": 5,
  "name": "Milk 1L",
  "slug": "milk-1l",
  "short_description": "Fresh milk",
  "long_description": "Fresh full cream milk 1 liter.",
  "base_price_amount": "5.50",
  "currency_code": "USD",
  "status": "active",
  "visibility": "public",
  "sort_order": 1
}
```

#### Behavior
- Creates item record
- Creates active item price record
- May optionally attach uploaded primary image reference

#### Validation
- name required
- slug required and unique per tenant
- base_price_amount required numeric decimal
- currency_code required
- category_id nullable but tenant-scoped if present
- status in `draft`, `active`, `archived`
- visibility in `public`, `hidden`

---

### GET `/api/v1/admin/items/{id}`
Returns item details with active price and image references.

---

### PUT `/api/v1/admin/items/{id}`
Updates item metadata and active price.

#### Notes
- If using pricing history, update logic may create a new price row instead of mutating old rows directly.
- This choice should be enforced consistently.

---

### DELETE `/api/v1/admin/items/{id}`
Archives or soft-deletes item.

---

### PATCH `/api/v1/admin/items/{id}/status`
Updates item lifecycle status.

#### Request
```json
{
  "status": "archived"
}
```

---

### PATCH `/api/v1/admin/items/{id}/visibility`
Updates public visibility.

#### Request
```json
{
  "visibility": "hidden"
}
```

---

## 5.7 Item Images

### POST `/api/v1/admin/items/{id}/images`
Uploads one or more images for an item.

#### Multipart fields
- image
- alt_text (optional)
- sort_order (optional)
- is_primary (optional)

#### Response
Returns uploaded image record.

---

### DELETE `/api/v1/admin/item-images/{imageId}`
Removes or archives an item image reference.

---

### PATCH `/api/v1/admin/item-images/{imageId}/primary`
Marks image as primary.

---

## 5.8 Service Entries

### GET `/api/v1/admin/services`
Returns structured manual service entries.

---

### POST `/api/v1/admin/services`
Creates a service entry.

#### Request
```json
{
  "name": "Home Cleaning",
  "slug": "home-cleaning",
  "description": "Professional home cleaning service.",
  "starting_price_amount": "50.00",
  "price_label": "Starting from",
  "currency_code": "USD",
  "status": "active",
  "visibility": "public",
  "sort_order": 1
}
```

#### Validation
- name required
- slug required and unique per tenant
- description recommended for public display
- price fields optional but normalized if provided

---

### GET `/api/v1/admin/services/{id}`
Returns one service entry.

---

### PUT `/api/v1/admin/services/{id}`
Updates service entry.

---

### DELETE `/api/v1/admin/services/{id}`
Archives or soft-deletes service entry.

---

## 5.9 Service FAQs

### GET `/api/v1/admin/service-faqs`
Returns service FAQs.

---

### POST `/api/v1/admin/service-faqs`
Creates FAQ entry.

#### Request
```json
{
  "question": "Do you work on weekends?",
  "answer": "Yes, by appointment.",
  "sort_order": 1,
  "status": "active"
}
```

---

### PUT `/api/v1/admin/service-faqs/{id}`
Updates FAQ.

---

### DELETE `/api/v1/admin/service-faqs/{id}`
Archives or removes FAQ based on policy.

---

## 5.10 Service Documents

### GET `/api/v1/admin/service-documents`
Returns uploaded service documents and processing status.

---

### POST `/api/v1/admin/service-documents`
Uploads PDF/document for service knowledge ingestion.

#### Multipart fields
- file

#### Validation
- file required
- allowed mime types must be controlled
- file size limits required

#### Response
Returns stored document record with upload/parse status.

---

### GET `/api/v1/admin/service-documents/{id}`
Returns document metadata and processing status.

---

## 5.11 Service Knowledge Review

### GET `/api/v1/admin/service-knowledge-chunks`
Returns extracted chunks for review.

#### Query params
- document_id
- extraction_status
- page
- per_page

---

### PATCH `/api/v1/admin/service-knowledge-chunks/{id}/approve`
Marks chunk as approved.

---

### PATCH `/api/v1/admin/service-knowledge-chunks/{id}/reject`
Marks chunk as rejected.

---

### PATCH `/api/v1/admin/service-knowledge-chunks/{id}`
Allows merchant editing/reviewing normalized chunk content before approval if enabled.

#### Notes
- If editing is supported, preserve audit trail.

---

## 5.12 QR Codes

### GET `/api/v1/admin/qr-codes`
Returns tenant QR codes.

---

### POST `/api/v1/admin/qr-codes`
Creates a QR code.

#### Request
```json
{
  "label": "Main Catalog QR",
  "destination_type": "catalog",
  "destination_payload": null
}
```

#### Validation
- label required
- destination_type in `catalog`, `services`, `landing`, `whatsapp`

---

### GET `/api/v1/admin/qr-codes/{id}`
Returns QR code metadata.

---

### PATCH `/api/v1/admin/qr-codes/{id}`
Updates QR label or destination metadata.

---

### PATCH `/api/v1/admin/qr-codes/{id}/deactivate`
Deactivates QR code.

---

### PATCH `/api/v1/admin/qr-codes/{id}/activate`
Reactivates QR code.

---

### POST `/api/v1/admin/qr-codes/{id}/regenerate`
Generates a new token for the QR and invalidates prior public route.

---

### GET `/api/v1/admin/qr-codes/{id}/download`
Returns downloadable QR asset or signed file URL.

---

## 5.13 Channel Connections (WhatsApp Foundation)

### GET `/api/v1/admin/channel-connections`
Returns current external channel connections.

---

### POST `/api/v1/admin/channel-connections/whatsapp`
Creates or begins WhatsApp connection setup.

#### Request
```json
{
  "external_phone_number": "+970...",
  "display_name": "Fresh Market WhatsApp"
}
```

#### Notes
- Exact flow depends on provider integration model.
- Credentials/secrets should not be stored raw in unsafe ways.

---

### GET `/api/v1/admin/channel-connections/{id}`
Returns connection state.

---

### PATCH `/api/v1/admin/channel-connections/{id}`
Updates display metadata or operational flags.

---

### POST `/api/v1/admin/channel-connections/{id}/disconnect`
Disconnects the channel safely.

---

## 5.14 Draft Orders Review

### GET `/api/v1/admin/draft-orders`
Returns merchant-reviewable draft orders.

#### Query params
- status
- customer_contact_id
- page
- per_page
- created_from
- created_to

---

### GET `/api/v1/admin/draft-orders/{id}`
Returns draft order details and line items.

---

### PATCH `/api/v1/admin/draft-orders/{id}/approve`
Approves draft order for next-stage use.

#### Notes
- In Phase 1, approval does not necessarily mean final invoice or payment completion.

---

### PATCH `/api/v1/admin/draft-orders/{id}/reject`
Rejects draft order.

---

### PATCH `/api/v1/admin/draft-orders/{id}`
Allows merchant adjustment before final review outcome.

#### Example request
```json
{
  "notes": "Customer requested delivery after 5 PM.",
  "items": [
    {
      "item_id": 12,
      "quantity": 3
    }
  ]
}
```

#### Rule
Any recomputation of subtotal must come from deterministic pricing logic.

---

## 5.15 Dashboard / Overview

### GET `/api/v1/admin/dashboard/overview`
Returns lightweight tenant dashboard summary.

#### Example response
```json
{
  "success": true,
  "message": "Overview fetched successfully.",
  "data": {
    "business_mode": "product",
    "catalog_counts": {
      "categories": 5,
      "items": 72,
      "active_items": 61
    },
    "public_page": {
      "is_published": true,
      "homepage_mode": "catalog"
    },
    "qr_counts": {
      "total": 3,
      "active": 2
    },
    "draft_orders": {
      "pending_review": 4
    }
  }
}
```

---

## 6. Public API Groups

## 6.1 Public Tenant Entry

### GET `/api/v1/public/tenants/{slug}`
Returns public business landing page payload.

#### Includes
- public business profile
- high-level CTA config
- published homepage mode
- public branding fields only

#### Must not include
- internal status fields
- audit data
- hidden items/services
- unpublished content

---

## 6.2 Public Catalog

### GET `/api/v1/public/tenants/{slug}/catalog`
Returns public catalog listing.

#### Query params
- category
- search
- page
- per_page
- sort

#### Response includes
- categories summary
- published public items only
- pagination meta

---

### GET `/api/v1/public/tenants/{slug}/catalog/items/{itemSlug}`
Returns public product details.

#### Must include
- product name
- description
- active public price
- image URLs
- business CTA data if needed

---

## 6.3 Public Services

### GET `/api/v1/public/tenants/{slug}/services`
Returns public service page data.

#### Includes
- active public service entries
- active FAQs
- public business intro

---

### GET `/api/v1/public/tenants/{slug}/services/{serviceSlug}`
Returns a single service detail payload if detail pages are supported.

---

## 6.4 QR Resolution

### GET `/api/v1/public/q/{token}`
Resolves QR token and returns redirect or structured resolution result.

### Behavior
- validate token exists
- validate token active
- increment analytics safely
- route to intended public destination

### Response options
Implementation may choose:
- direct HTTP redirect
- JSON response for frontend-controlled routing

Preferred for public browser behavior:
- redirect

---

## 7. Webhook and Internal API Groups

## 7.1 WhatsApp Webhook Verification

### GET `/api/v1/webhooks/whatsapp`
Provider verification endpoint if required by provider.

---

## 7.2 WhatsApp Inbound Webhook

### POST `/api/v1/webhooks/whatsapp`
Receives inbound WhatsApp events.

### Required behavior
- validate signature / verification mechanism
- persist raw payload
- map tenant/channel context safely
- enqueue deeper processing
- return fast acknowledgment

### Must not do synchronously
- full AI response generation
- expensive retrieval pipeline
- large-scale side effects

---

## 7.3 Internal Document Processing Hooks

### POST `/api/v1/internal/service-documents/{id}/process-complete`
Internal-only hook for parse pipeline completion if external processor is used.

### Rule
Must never be publicly exposed without strong internal authentication.

---

## 8. Validation and Error Strategy

## 8.1 Validation Errors
Use standard field-level validation responses.

### Example
```json
{
  "success": false,
  "message": "Validation failed.",
  "errors": {
    "name": ["The name field is required."],
    "slug": ["The slug has already been taken."]
  }
}
```

---

## 8.2 Authorization Errors
Return clear but safe authorization failures.

### Example
```json
{
  "success": false,
  "message": "You are not authorized to access this resource."
}
```

---

## 8.3 Not Found Behavior
For tenant-scoped admin resources:
- return not found if resource is outside tenant scope
- do not leak that another tenant owns the resource

For public resources:
- return not found for hidden or unpublished content

---

## 9. Pagination Strategy

Recommended standard query params:
- `page`
- `per_page`

Recommended meta structure:
```json
{
  "meta": {
    "current_page": 1,
    "per_page": 15,
    "total": 120,
    "last_page": 8
  }
}
```

---

## 10. Filtering and Sorting Strategy

### Admin APIs
Allow safe filter/sort by:
- search
- status
- visibility
- category
- created_at
- updated_at
- sort_order

### Public APIs
Allow lighter filter/sort by:
- category
- search
- sort

Do not expose admin-only sorting/filtering fields publicly.

---

## 11. File Upload Contract Direction

### Preferred pattern
Two acceptable approaches:

#### Option A — Direct backend upload
- multipart upload to backend
- backend validates and stores file

#### Option B — Signed upload flow
- client requests signed upload URL
- client uploads to storage
- backend finalizes file record

### Phase 1 recommendation
Use direct backend upload first for simplicity unless traffic/security architecture strongly requires signed uploads immediately.

---

## 12. Audit-Critical Endpoint Events

The following API actions should trigger audit events:
- tenant creation
- business profile update
- public page publish changes
- category create/update/archive
- item create/update/archive
- item price changes
- service entry create/update/archive
- service chunk approve/reject/edit
- QR create/update/deactivate/regenerate
- channel connection connect/disconnect
- draft order approve/reject/manual adjustment

---

## 13. API Security Notes

### Admin endpoints
- require auth middleware
- require tenant membership middleware
- require role/permission checks
- require tenant-safe resource resolution

### Public endpoints
- allow anonymous access
- serve public content only
- use caching carefully
- rate limit where appropriate

### Webhooks
- verify authenticity
- store payload
- idempotency handling where provider supports repeated delivery

---

## 14. Recommended Route Group Structure

### Admin
- `/api/v1/admin/auth/*`
- `/api/v1/admin/tenants/*`
- `/api/v1/admin/business-profile`
- `/api/v1/admin/public-page-settings`
- `/api/v1/admin/categories/*`
- `/api/v1/admin/items/*`
- `/api/v1/admin/item-images/*`
- `/api/v1/admin/services/*`
- `/api/v1/admin/service-faqs/*`
- `/api/v1/admin/service-documents/*`
- `/api/v1/admin/service-knowledge-chunks/*`
- `/api/v1/admin/qr-codes/*`
- `/api/v1/admin/channel-connections/*`
- `/api/v1/admin/draft-orders/*`
- `/api/v1/admin/dashboard/*`

### Public
- `/api/v1/public/tenants/{slug}`
- `/api/v1/public/tenants/{slug}/catalog`
- `/api/v1/public/tenants/{slug}/catalog/items/{itemSlug}`
- `/api/v1/public/tenants/{slug}/services`
- `/api/v1/public/tenants/{slug}/services/{serviceSlug}`
- `/api/v1/public/q/{token}`

### Webhooks/Internal
- `/api/v1/webhooks/whatsapp`
- `/api/v1/internal/service-documents/*`

---

## 15. Future-Safe Expansion Points

These API groups may be added later without breaking the Phase 1 foundation:
- inventory
- branches
- carts
- final orders
- invoices
- payments
- customer accounts
- appointments
- promotions
- loyalty
- AI settings and reply policies

---

## 16. Final Recommendation

This contract should be treated as the Phase 1 external behavior blueprint.

It intentionally keeps:
- admin workflows explicit
- public content safe and minimal
- webhook flows resilient
- money-sensitive updates deterministic
- future extension paths open

---

## 17. Next Step

After API contracts, the next document should be:

**IMPLEMENTATION_BACKLOG_PHASE_1.md**

That backlog should convert architecture and contracts into:
- milestones
- modules
- tasks
- execution order
- dependency map
- production launch sequence

This API document is the operating contract for building the first release safely and cleanly.

