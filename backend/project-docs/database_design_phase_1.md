# DATABASE_DESIGN_PHASE_1.md

## 1. Purpose

This document defines the Phase 1 database design for the AI Commerce Platform.

The design must satisfy these goals:
- strict multi-tenant separation
- production-grade extensibility
- clean support for both product and service businesses
- safe handling of money-related data
- support for public pages, QR, WhatsApp flows, and future AI workflows

This is a **Phase 1 production schema direction**, not a final forever schema. It should stay lean where possible while preserving future expansion paths.

---

## 2. Design Principles

### 2.1 Tenant-First
Every business belongs to a tenant. Tenant isolation is the most important structural rule.

### 2.2 Deterministic Financial Data
Money-related fields must be stored explicitly in structured columns. Do not rely on AI text as a financial source of truth.

### 2.3 Extensible but Not Bloated
Include fields and tables needed for the first sellable release. Leave room for future extensions, but do not over-design every future workflow into Phase 1.

### 2.4 Approval Before AI Authority
For service knowledge extracted from documents, approved data must be distinguished from raw extracted data.

### 2.5 Public vs Internal Separation
The schema must support safe public rendering without exposing internal-only records.

---

## 3. Main Entity Groups

### Group A — Identity and Tenant Ownership
- users
- tenants
- tenant_users
- subscriptions

### Group B — Business Configuration
- business_profiles
- public_page_settings
- tenant_feature_flags (optional later)

### Group C — Product Catalog
- categories
- items
- item_prices
- item_images

### Group D — Service Knowledge
- service_documents
- service_knowledge_chunks
- service_entries
- service_faqs

### Group E — Public Access and QR
- qr_codes

### Group F — Messaging and Contacts
- customer_contacts
- channel_connections
- inbound_messages
- outbound_messages
- ai_conversations
- ai_runs

### Group G — Draft Capture
- draft_orders
- draft_order_items

### Group H — Audit and Operations
- audit_logs

---

## 4. Core Tables

## 4.1 users
Global user records for platform and merchant users.

### Columns
- id
- name
- email
- password_hash
- email_verified_at
- status
- last_login_at
- created_at
- updated_at

### Notes
- One user may belong to multiple tenants in the future.
- Avoid tenant-specific columns here.

---

## 4.2 tenants
Represents a merchant workspace/business account.

### Columns
- id
- owner_user_id
- name
- slug
- business_mode (`product`, `service`, `hybrid` reserved later)
- status (`draft`, `active`, `suspended`, `archived`)
- primary_language
- currency_code
- timezone
- onboarding_completed_at
- created_at
- updated_at

### Constraints
- slug unique globally
- owner_user_id references users.id

### Notes
- `hybrid` can stay reserved for future support, even if Phase 1 UX emphasizes choosing product or service mode.

---

## 4.3 tenant_users
Pivot table for user membership inside tenant workspaces.

### Columns
- id
- tenant_id
- user_id
- role (`owner`, `admin`, `staff`)
- status (`active`, `invited`, `disabled`)
- created_at
- updated_at

### Constraints
- unique (tenant_id, user_id)

### Notes
- This is the authorization anchor for merchant-side access.

---

## 4.4 subscriptions
Stores commercial plan information for each tenant.

### Columns
- id
- tenant_id
- plan_code
- status (`trial`, `active`, `past_due`, `canceled`, `expired`)
- starts_at
- ends_at
- billing_cycle
- created_at
- updated_at

### Notes
- Keep minimal in Phase 1.
- Full billing integration can expand later.

---

## 4.5 business_profiles
Stores merchant-facing business identity and public-facing metadata.

### Columns
- id
- tenant_id
- business_name
- short_about
- phone_number
- whatsapp_number
- address_text
- logo_path
- cover_image_path
- public_visibility (`private`, `public`)
- created_at
- updated_at

### Constraints
- unique (tenant_id)

### Notes
- Keep this separate from `tenants` so tenant-level system identity and business profile remain conceptually distinct.

---

## 4.6 public_page_settings
Controls public page rendering and publishing behavior.

### Columns
- id
- tenant_id
- homepage_mode (`catalog`, `services`, `landing`)
- is_published
- theme_mode (nullable, future use)
- primary_cta_type (`whatsapp`, `catalog`, `services`)
- primary_cta_payload (nullable)
- created_at
- updated_at

### Constraints
- unique (tenant_id)

### Notes
- Keep simple in Phase 1; do not overbuild theming yet.

---

## 5. Product Catalog Tables

## 5.1 categories
Hierarchical grouping for product businesses.

### Columns
- id
- tenant_id
- parent_id (nullable)
- name
- slug
- description (nullable)
- sort_order
- status (`active`, `archived`)
- created_at
- updated_at

### Constraints
- unique (tenant_id, slug)
- parent_id references categories.id

### Notes
- Parent-child nesting should be simple and safe.
- Keep support for uncategorized items by allowing item.category_id to be nullable.

---

## 5.2 items
Primary product/item table.

### Columns
- id
- tenant_id
- category_id (nullable)
- name
- slug
- short_description (nullable)
- long_description (nullable)
- item_type (`product` for Phase 1, extensible later)
- status (`draft`, `active`, `archived`)
- visibility (`public`, `hidden`)
- primary_image_id (nullable)
- sort_order
- created_by_user_id (nullable)
- updated_by_user_id (nullable)
- created_at
- updated_at

### Constraints
- unique (tenant_id, slug)
- category_id references categories.id
- primary_image_id references item_images.id (nullable)

### Notes
- Keep room for broader item modeling later, but Phase 1 should treat these as products.

---

## 5.3 item_prices
Stores explicit product pricing.

### Columns
- id
- tenant_id
- item_id
- currency_code
- base_price_amount
- compare_at_price_amount (nullable)
- pricing_status (`active`, `inactive`)
- effective_from (nullable)
- effective_to (nullable)
- created_at
- updated_at

### Constraints
- item_id references items.id

### Notes
- Use decimal/numeric types with appropriate precision.
- Monetary values must be explicit and structured.
- Even if the UI only uses one active price initially, separating pricing keeps future promotions/versioning cleaner.

---

## 5.4 item_images
Stores item image references.

### Columns
- id
- tenant_id
- item_id
- storage_path
- alt_text (nullable)
- sort_order
- is_primary
- created_at
- updated_at

### Constraints
- item_id references items.id

### Notes
- Object storage path only; do not store large binaries directly in the database.

---

## 6. Service Knowledge Tables

## 6.1 service_documents
Uploaded files for service businesses.

### Columns
- id
- tenant_id
- original_filename
- storage_path
- mime_type
- file_size_bytes
- upload_status (`uploaded`, `processing`, `processed`, `failed`)
- parse_status (`pending`, `parsed`, `failed`)
- uploaded_by_user_id
- created_at
- updated_at

### Constraints
- uploaded_by_user_id references users.id

### Notes
- Separate upload lifecycle from extracted knowledge lifecycle.

---

## 6.2 service_knowledge_chunks
Stores extracted chunks from uploaded service documents.

### Columns
- id
- tenant_id
- service_document_id
- chunk_index
- raw_text
- normalized_text
- embedding_vector (implementation-specific)
- extraction_status (`raw`, `reviewed`, `approved`, `rejected`)
- approved_by_user_id (nullable)
- approved_at (nullable)
- created_at
- updated_at

### Constraints
- service_document_id references service_documents.id

### Notes
- In PostgreSQL + pgvector, `embedding_vector` may be an actual vector column.
- Only approved chunks should be used for AI grounding in production flows.

---

## 6.3 service_entries
Structured manual service records.

### Columns
- id
- tenant_id
- name
- slug
- description
- starting_price_amount (nullable)
- price_label (nullable)
- currency_code (nullable)
- status (`draft`, `active`, `archived`)
- visibility (`public`, `hidden`)
- sort_order
- created_by_user_id (nullable)
- updated_by_user_id (nullable)
- created_at
- updated_at

### Constraints
- unique (tenant_id, slug)

### Notes
- `price_label` supports service-style pricing such as “starting from” or “contact us”.

---

## 6.4 service_faqs
Structured frequently asked questions for service businesses.

### Columns
- id
- tenant_id
- question
- answer
- sort_order
- status (`draft`, `active`, `archived`)
- created_at
- updated_at

---

## 7. Public Access and QR

## 7.1 qr_codes
Tenant-scoped QR destinations.

### Columns
- id
- tenant_id
- label
- token
- destination_type (`catalog`, `services`, `landing`, `whatsapp`)
- destination_payload (nullable JSON/text)
- is_active
- scan_count
- last_scanned_at (nullable)
- created_by_user_id (nullable)
- created_at
- updated_at

### Constraints
- token unique globally

### Notes
- `destination_payload` may store route metadata or deep-link configuration.
- Scan analytics can be expanded later, but this table should support basic counts now.

---

## 8. Messaging and AI Tables

## 8.1 channel_connections
Represents external channel bindings, starting with WhatsApp.

### Columns
- id
- tenant_id
- channel_type (`whatsapp`)
- external_account_id
- external_phone_number
- display_name (nullable)
- connection_status (`pending`, `active`, `disconnected`, `failed`)
- credentials_reference (nullable)
- created_at
- updated_at

### Notes
- Do not store raw secrets directly if avoidable; use secure secret references.

---

## 8.2 customer_contacts
Stores end-customer identity per tenant.

### Columns
- id
- tenant_id
- channel_connection_id (nullable)
- external_contact_id (nullable)
- phone_number (nullable)
- display_name (nullable)
- first_seen_at
- last_seen_at
- created_at
- updated_at

### Constraints
- uniqueness strategy may depend on phone normalization per tenant/channel

### Notes
- A customer is tenant-scoped; the same phone can appear under different tenants safely.

---

## 8.3 inbound_messages
Stores inbound channel messages before and after processing.

### Columns
- id
- tenant_id
- channel_connection_id
- customer_contact_id
- provider_message_id (nullable)
- message_type (`text`, `image`, `audio`, `document`, `unknown`)
- raw_payload
- normalized_text (nullable)
- processing_status (`received`, `queued`, `processed`, `failed`)
- received_at
- created_at
- updated_at

### Constraints
- channel_connection_id references channel_connections.id
- customer_contact_id references customer_contacts.id

### Notes
- Persist first, process after.
- `raw_payload` is valuable for debugging and replay-safe workflows.

---

## 8.4 outbound_messages
Stores system-generated outbound replies.

### Columns
- id
- tenant_id
- channel_connection_id
- customer_contact_id
- in_reply_to_inbound_message_id (nullable)
- provider_message_id (nullable)
- message_type (`text`, `template`, `interactive`, `unknown`)
- message_body
- delivery_status (`queued`, `sent`, `delivered`, `failed`)
- sent_at (nullable)
- created_at
- updated_at

### Constraints
- in_reply_to_inbound_message_id references inbound_messages.id

---

## 8.5 ai_conversations
Logical grouping for a customer conversation thread.

### Columns
- id
- tenant_id
- channel_connection_id
- customer_contact_id
- status (`active`, `closed`)
- created_at
- updated_at

### Notes
- Useful for future conversation memory and threading.

---

## 8.6 ai_runs
Stores AI processing attempts for traceability.

### Columns
- id
- tenant_id
- ai_conversation_id (nullable)
- inbound_message_id (nullable)
- run_type (`reply_generation`, `draft_extraction`, `classification`, `retrieval`)
- model_name
- input_summary (nullable)
- output_summary (nullable)
- confidence_score (nullable)
- status (`started`, `completed`, `failed`, `rejected`)
- created_at
- updated_at

### Notes
- Avoid storing excessive full prompt/response bodies blindly if privacy/cost concerns exist; summaries and secure trace handling are better.

---

## 9. Draft Capture Tables

## 9.1 draft_orders
Represents merchant-reviewable order drafts produced from customer input.

### Columns
- id
- tenant_id
- customer_contact_id (nullable)
- source_type (`whatsapp`, `web`, `manual`)
- source_reference_id (nullable)
- status (`draft`, `under_review`, `approved`, `rejected`, `expired`)
- currency_code
- subtotal_amount (nullable)
- notes (nullable)
- created_by_ai_run_id (nullable)
- reviewed_by_user_id (nullable)
- reviewed_at (nullable)
- created_at
- updated_at

### Notes
- `subtotal_amount` should be computed only from validated system item prices, not directly from AI output.
- In Phase 1 this is still a draft, not a final accounting order.

---

## 9.2 draft_order_items
Structured line items for a draft order.

### Columns
- id
- draft_order_id
- tenant_id
- item_id
- item_name_snapshot
- quantity
- unit_price_amount
- line_total_amount
- extraction_confidence (nullable)
- created_at
- updated_at

### Constraints
- draft_order_id references draft_orders.id
- item_id references items.id

### Notes
- Keep snapshot fields to preserve what was reviewed at the time.
- Prices must come from validated current system records during draft creation.

---

## 10. Audit and Operational Tables

## 10.1 audit_logs
General-purpose audit trail.

### Columns
- id
- tenant_id (nullable for platform-level actions)
- actor_user_id (nullable)
- actor_type (`user`, `system`, `ai`, `webhook`)
- entity_type
- entity_id
- action
- before_snapshot (nullable)
- after_snapshot (nullable)
- metadata (nullable)
- created_at

### Notes
- Do not audit everything blindly; focus on sensitive actions and business-critical mutations.
- Pricing changes, QR changes, publication changes, service approval changes, and admin profile changes should be captured.

---

## 11. Recommended Relationships Summary

### Tenant ownership
- users 1—many tenants (via owner_user_id)
- users many—many tenants (via tenant_users)

### Product side
- tenants 1—many categories
- tenants 1—many items
- items 1—many item_prices
- items 1—many item_images
- categories 1—many items

### Service side
- tenants 1—many service_documents
- service_documents 1—many service_knowledge_chunks
- tenants 1—many service_entries
- tenants 1—many service_faqs

### Messaging side
- tenants 1—many channel_connections
- tenants 1—many customer_contacts
- channel_connections 1—many inbound_messages
- channel_connections 1—many outbound_messages
- customer_contacts 1—many inbound_messages
- customer_contacts 1—many outbound_messages

### Draft side
- tenants 1—many draft_orders
- draft_orders 1—many draft_order_items

---

## 12. Suggested Indexing Strategy

### High-priority indexes
- tenants.slug
- tenant_users (tenant_id, user_id)
- categories (tenant_id, slug)
- items (tenant_id, slug)
- items (tenant_id, status, visibility)
- item_prices (tenant_id, item_id, pricing_status)
- service_entries (tenant_id, slug)
- service_knowledge_chunks (tenant_id, extraction_status)
- qr_codes.token
- qr_codes (tenant_id, is_active)
- channel_connections (tenant_id, channel_type)
- customer_contacts (tenant_id, phone_number)
- inbound_messages (tenant_id, processing_status, received_at)
- outbound_messages (tenant_id, delivery_status)
- draft_orders (tenant_id, status, created_at)
- audit_logs (tenant_id, entity_type, entity_id)

### Vector index
If pgvector is used, add appropriate vector index strategy for approved service knowledge chunks only.

---

## 13. Soft Delete Guidance

### Recommended soft delete / archival candidates
- items
- categories
- service_entries
- service_faqs
- qr_codes (or logical deactivation)
- draft_orders (depending on business policy)

### Hard delete should be restricted for
- audit logs
- message history if needed for compliance/debugging
- price history when used operationally

---

## 14. Status Modeling Guidance

Use explicit enums/status fields for clarity.
Do not overload a single boolean to represent complex lifecycle state.

Examples:
- item status: `draft`, `active`, `archived`
- page publish state: boolean or explicit publish flag
- service chunk status: `raw`, `reviewed`, `approved`, `rejected`
- draft order status: `draft`, `under_review`, `approved`, `rejected`, `expired`

---

## 15. Money Column Guidance

All money columns should:
- use decimal/numeric with fixed precision
- carry clear naming such as `_amount`
- always pair with currency where cross-currency ambiguity is possible

Recommended pattern:
- `base_price_amount`
- `starting_price_amount`
- `subtotal_amount`
- `line_total_amount`

Do not store money as float.

---

## 16. JSON Usage Guidance

Use JSON only where flexibility is useful and structured schema is not yet justified.

Safe Phase 1 examples:
- qr_codes.destination_payload
- audit_logs.metadata
- inbound_messages.raw_payload

Avoid putting core business fields inside JSON when they are queried, validated, or money-sensitive.

---

## 17. Phase 1 Minimal ER Direction

A practical minimal relationship view:
- tenant owns business profile and page settings
- tenant has either product catalog, service knowledge, or both later
- tenant has QR codes
- tenant may connect WhatsApp
- customer messages create AI runs
- AI runs may create draft orders
- merchant reviews draft orders

---

## 18. Migration Strategy Notes

### Initial migration order
1. users
2. tenants
3. tenant_users
4. subscriptions
5. business_profiles
6. public_page_settings
7. categories
8. items
9. item_prices
10. item_images
11. service_documents
12. service_knowledge_chunks
13. service_entries
14. service_faqs
15. qr_codes
16. channel_connections
17. customer_contacts
18. inbound_messages
19. outbound_messages
20. ai_conversations
21. ai_runs
22. draft_orders
23. draft_order_items
24. audit_logs

### Rule
Build foundational auth/tenant tables first, then content tables, then messaging/AI tables.

---

## 19. What We Intentionally Delayed

These are intentionally not first-class schema priorities in Phase 1:
- stock movements
- warehouses
- suppliers
- purchase invoices
- tax rules engine
- payment ledgers
- shipment tracking
- branch hierarchy complexity
- promotion engine
- variant matrix complexity

They may be added later in dedicated modules without polluting the first-release schema.

---

## 20. Final Recommendations

### Recommended active Phase 1 product schema
Use:
- categories
- items
- item_prices
- item_images

This is enough for a polished launch without forcing inventory complexity.

### Recommended active Phase 1 service schema
Use:
- service_documents
- service_knowledge_chunks
- service_entries
- service_faqs

This gives both manual and document-driven service onboarding.

### Recommended active Phase 1 messaging schema
Use:
- channel_connections
- customer_contacts
- inbound_messages
- outbound_messages
- ai_runs
- draft_orders
- draft_order_items

This is enough to support WhatsApp AI replies and safe draft extraction.

---

## 21. Next Step

After this schema direction is approved, the next document should be:

**API_CONTRACTS_PHASE_1.md**

That document should define:
- admin endpoints
- public endpoints
- webhook endpoints
- core request/response contracts
- validation expectations
- authorization boundaries

This schema is the production foundation for building Phase 1 cleanly and safely.

