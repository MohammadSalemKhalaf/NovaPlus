# AGENTS.md

## 0. Agent Bootstrap (MANDATORY EXECUTION FLOW)

Before performing ANY task, the agent MUST execute the following sequence:

### Step 1: Load Core Memory
- Read AGENTS.md بالكامل كـ source of truth
- فهم architecture + rules + constraints

### Step 2: Load Project Rules
Agent MUST read ALL files inside:

`project-docs/project-rules/`

Including:
- AI_RULES.md
- IMPLEMENTATION_RULES.md
- API_TESTING_RULES.md
- PROMPT_TEMPLATE.md

These files are NOT optional.
They are considered EXTENSIONS of AGENTS.md.

### Step 3: Merge Context
Agent MUST:
- combine AGENTS.md + project-rules
- treat them as one unified rule system

### Step 4: Execution
Only after reading ALL rules:

Agent can:
- implement code
- modify code
- create endpoints
- update Postman

### Strict Enforcement
If agent does NOT read project rules:

- Implementation is INVALID ❌
- Task is considered FAILED ❌

### Output Behavior
Before starting any implementation, agent MUST internally confirm:

"AGENT MEMORY LOADED ✅"

### Final Rule
This bootstrap step is MANDATORY for every task.
It cannot be skipped under any condition.

## 1. Project Identity

**Project Name:** AI Commerce Platform  
**Project Type:** Multi-tenant SaaS platform for AI-assisted commerce, ordering, catalog publishing, service knowledge delivery, QR routing, and operational automation.  
**Primary Objective:** Build a production-grade, secure, extensible system that can serve many businesses from one core platform while allowing each tenant to maintain its own catalog, knowledge, branding, channels, and operational rules.

This project must support two primary tenant modes:
- **Product-based businesses**: stores, supermarkets, restaurants, retail, inventory-based sellers.
- **Service-based businesses**: clinics, salons, agencies, service offices, appointment or consultation businesses.

The platform must be designed from the beginning as a **generic engine**, not as a one-off vertical application.

---

## 2. North Star

The system should allow a merchant to subscribe, configure their business, upload or manage their own data, connect customer communication channels, generate QR entry points, and let AI assist with customer interaction and order/request capture.

The platform must reduce manual back-office work while preserving high financial accuracy, strict access control, and strong tenant isolation.

---

## 3. Phase Priority

### Current Priority: Phase 1
The immediate delivery target is:
- Tenant onboarding
- Merchant admin foundation
- Product catalog management
- Service knowledge ingestion
- Public catalog / public service pages
- QR generation and routing
- WhatsApp AI response foundation
- Draft order / draft request capture

### Explicit Phase 1 Priority Order
1. Catalog
2. Admin dashboard
3. QR
4. Public customer entry points
5. WhatsApp AI replies
6. Draft order capture

Everything in current planning and implementation must optimize for shipping this first sellable production milestone.

---

## 4. Core Product Principles

### 4.1 Multi-Tenant First
This is not a single-business system. Every core decision must be compatible with multi-tenant SaaS operation.

Requirements:
- Every business is a tenant/workspace.
- All tenant data must be isolated.
- Every query, job, event, and integration must be tenant-aware.
- Public links and QR tokens must resolve safely to tenant-scoped resources only.

### 4.2 Generic Data Ownership
The platform provides the engine. Each tenant provides its own business data.

Examples:
- A supermarket enters products, prices, categories, images.
- A service company uploads PDFs, service descriptions, pricing, FAQs.

The platform must never assume fixed products or fixed business categories at the core architecture level.

### 4.3 AI Is an Assistant, Not the Source of Truth
LLMs may help interpret, classify, summarize, and extract candidate structure from messy input.

LLMs must never be treated as the authoritative source for:
- prices
- totals
- taxes
- discount rules
- payment state
- accounting truth
- inventory truth unless explicitly validated against system records

### 4.4 Production-First Mindset
Every design choice must be evaluated through:
- correctness
- security
- performance
- observability
- recoverability
- auditability
- maintainability

---

## 5. Primary Business Flows

### 5.1 Product Business Flow
A merchant:
1. creates a tenant
2. configures business profile
3. creates categories and products
4. publishes a public catalog
5. generates QR code
6. optionally connects WhatsApp
7. receives customer questions or order intents
8. reviews AI-generated draft orders

### 5.2 Service Business Flow
A merchant:
1. creates a tenant
2. configures business profile
3. uploads PDFs or structured service information
4. reviews parsed knowledge
5. publishes service page or QR entry point
6. connects WhatsApp
7. receives AI-assisted service inquiries and draft requests

---

## 6. Phase 1 Scope Guardrails

### In Scope
- Multi-tenant foundation
- Merchant onboarding
- Business profiles
- Product catalog
- Service knowledge upload
- Public business pages
- QR generation and destination routing
- WhatsApp integration foundation
- AI retrieval-grounded replies
- Draft order/request capture
- Admin dashboard for merchants
- Roles/permissions foundation
- Audit logging foundation

### Out of Scope for Phase 1
Unless explicitly re-approved and planned, do not expand Phase 1 to include:
- full accounting ledger
- final tax engine
- demand prediction
- invoice OCR automation
- voice ordering
- route optimization / delivery orchestration
- loyalty points
- rewards systems
- advanced recommendation engine
- autonomous decisioning over money-sensitive actions

---

## 7. Architecture Rules

### 7.1 Preferred Architecture Style
Use a **modular monolith** for Phase 1 with clean module boundaries and future extraction paths.

Reasoning:
- lower operational complexity
- faster production delivery
- easier local development
- clearer domain boundaries before splitting services

### 7.2 Required Architectural Qualities
All modules must be designed for:
- tenant awareness
- explicit authorization
- idempotent integration handling where applicable
- event emission hooks for future decoupling
- queue-safe async workloads
- structured error handling

### 7.3 Initial Technical Direction
Preferred baseline unless a stronger reason appears:
- **Backend:** Laravel
- **Admin / Public UI:** Next.js
- **Database:** PostgreSQL
- **Cache / Queue:** Redis
- **Storage:** S3-compatible object storage
- **Automation:** n8n
- **Vector search:** pgvector initially
- **Observability:** structured logs, metrics, tracing-ready instrumentation, audit logs

---

## 8. Module Boundaries

### 8.1 Identity and Access Module
Owns:
- authentication
- sessions/tokens
- merchant user accounts
- tenant membership
- roles and permissions

### 8.2 Tenant / Workspace Module
Owns:
- tenant record
- business configuration
- branding
- locale
- timezone
- currency
- subscription feature flags

### 8.3 Catalog Module
Owns:
- categories
- products/items
- variants
- media
- availability
- publication state
- price records

### 8.4 Service Knowledge Module
Owns:
- document uploads
- document parsing
- chunk storage
- extracted service content
- FAQ records
- approval/review workflow

### 8.5 QR Module
Owns:
- QR generation
- QR metadata
- destination mapping
- QR analytics
- activation/deactivation

### 8.6 Messaging Integration Module
Owns:
- WhatsApp webhook intake
- normalized inbound message records
- outbound delivery tracking
- contact identity mapping

### 8.7 AI Orchestration Module
Owns:
- intent classification
- retrieval grounding
- response generation
- draft extraction
- confidence scoring
- escalation to human review

### 8.8 Draft Orders / Draft Requests Module
Owns:
- extracted structured drafts
- validation against known business records
- review lifecycle
- merchant acceptance/edit/rejection

### 8.9 Admin Dashboard Module
Owns:
- merchant-facing management views
- catalog admin views
- service knowledge review views
- QR management views
- message review queue
- draft review queue

### 8.10 Audit Module
Owns:
- security-sensitive action logs
- admin mutation history
- AI suggestion vs final approved action trail
- pricing change history

---

## 9. Security Rules

### 9.1 Absolute Requirements
- All admin endpoints require authentication and authorization.
- All reads/writes must be tenant-scoped.
- Never trust client-supplied tenant identifiers without verification.
- Validate webhook signatures for external providers.
- Protect secrets using proper environment and secret-management practices.
- Log security-sensitive actions.
- Use least-privilege access for infrastructure and integrations.

### 9.2 Money-Sensitive Safety
For anything involving money or order value:
- pricing must come from deterministic system records
- totals must be computed by business logic
- AI outputs must be treated as candidate input only
- merchant confirmation is required before finalization in ambiguous flows

### 9.3 Upload Safety
- Validate file type and size
- Scan or gate unsafe content as needed
- Avoid direct public exposure of raw internal files unless intended
- Use signed access or controlled file serving where appropriate

### 9.4 Public Endpoint Safety
Public pages and QR routes must:
- expose only intended tenant-public data
- never leak internal admin metadata
- never expose storage internals
- be rate-limited and abuse-aware where relevant

### 9.5 Tenant Scope and Sensitive Data Safety
- NEVER expose sensitive data in API responses, logs, or debug payloads.
- ALWAYS scope data access by `tenant_id` at query level.
- NEVER trust frontend-supplied `tenant_id`; tenant context must be resolved from authenticated membership/session and enforced server-side.

---

## 10. Performance Rules

### 10.1 General
- Prefer deterministic code paths over repeated LLM calls.
- Use queues for long-running or heavy background tasks.
- Use pagination for admin listings.
- Use caching where correctness is preserved.
- Optimize mobile-first public experiences.

### 10.2 LLM Cost and Latency Discipline
Agents and developers must not call LLMs for work that can be done reliably by:
- exact matching
- rules engines
- database lookup
- deterministic parsers
- cached retrieval

### 10.3 Catalog Scale Discipline
Design catalog retrieval to support:
- large tenant catalogs
- fast public browsing
- structured filtering
- incremental expansion later

### 10.4 Query Performance Engineering (Mandatory)
- NO collection filtering for production endpoints when database filtering is possible.
- ALWAYS perform filtering, sorting, and aggregation at DB level.
- ALWAYS use explicit `select()` with required columns only; never rely on `select *` in application queries.
- MUST prevent N+1 queries by design and review.
- MUST use eager loading when related data is required, while limiting selected relation columns.

### 10.5 Query Optimization Rules
- NEVER fetch full tables for request/response flows.
- ALWAYS paginate list endpoints.
- ALWAYS limit columns for lists and summaries.
- NEVER execute database calls inside loops when a set-based query can solve it.

### 10.6 Indexing Strategy (Critical)
- Agents and contributors MUST analyze every new or modified query path.
- If a query contains `WHERE`, `JOIN`, or `ORDER BY`, index evaluation is mandatory.
- Add indexes when needed for filtering, join, and sorting paths.
- Common index candidates that must be evaluated early include: `tenant_id`, `device_id`, `item_id`, `category_id`.
- Indexing decisions must consider read/write trade-offs and expected tenant scale.

### 10.7 Response Optimization
- DTO/resource mapping is REQUIRED for API responses.
- NO heavy payloads for list endpoints.
- DO NOT include unnecessary relations.
- Prefer lightweight list responses and provide detail endpoints for expanded data.

### 10.8 Cache Strategy (Light)
Cache is allowed only where correctness is preserved and invalidation is explicit.

Initial read-heavy targets:
- public catalog
- public stores

Rules:
- Use Redis when available.
- Define deterministic cache keys including tenant/public scope.
- Define explicit TTL per endpoint/use case.
- Invalidate relevant cache entries on create/update/delete or publication-state changes.

---

## 11. Accuracy Rules

### 11.1 Retrieval Grounding
AI responses must be grounded in tenant-approved data only.

Permitted grounding sources in Phase 1:
- product catalog records
- approved service knowledge chunks
- tenant FAQ records
- approved business profile data

### 11.2 Hallucination Avoidance
If the data is missing or unclear, the system should prefer:
- safe fallback wording
- clarification request
- human review routing

over made-up answers.

### 11.3 Confidence Thresholding
Where extraction confidence is used, low confidence must trigger:
- clarification request
- review queue routing
- refusal to finalize any money-sensitive outcome automatically

---

## 12. Data Rules

### 12.1 Source of Truth
System records are the source of truth, not conversation text.

### 12.2 Auditability
Any sensitive mutation should be reconstructable later, including:
- who changed it
- when it changed
- what it changed from and to
- which tenant it belonged to

### 12.3 Soft vs Hard Deletes
Avoid destructive deletion for records likely to matter operationally or financially. Prefer archival or soft-delete patterns when appropriate.

---

## 13. Coding Rules for All Agents and Contributors

### 13.1 General Engineering Quality
All implementation must be:
- production-oriented
- tested
- explicit
- readable
- modular
- failure-aware

### 13.2 Forbidden Habits
Do not:
- hardcode tenant-specific business logic into the platform core
- bypass authorization for convenience
- mix admin logic and public logic carelessly
- let AI directly finalize financial outputs
- store important values only inside free-form JSON when structured schema is clearly needed
- add hidden side effects in request handlers without logging or visibility

### 13.3 Preferred Practices
Prefer:
- domain-focused naming
- explicit validation
- service-layer or action-layer organization where appropriate
- event hooks for important lifecycle steps
- DTO/resource patterns where useful
- versioned public APIs if exposure grows

### 13.4 Validation Discipline
- ALWAYS use FormRequest validation for HTTP write operations and complex filters.
- NEVER trust raw input without explicit validation and normalization.
- Validation must include tenant ownership checks for entity references.

### 13.5 Agent Behavior Upgrade
Agent and contributor behavior must remain production-first:
- think production-first for every implementation decision
- do not write naive queries
- do not over-engineer beyond Phase 1 scope
- do not break working features while optimizing
- optimize from first implementation, not as an afterthought

---

## 14. Public vs Internal API Rule
The system must clearly separate:
- public customer-facing endpoints
- authenticated merchant/admin endpoints
- internal processing endpoints/webhooks

Never blur these concerns.

---

## 15. AI Behavior Rules

### 15.1 AI May Do
- interpret messy customer text
- map likely items/services
- answer grounded product/service questions
- summarize approved business knowledge
- propose draft order/request structures

### 15.2 AI May Not Do
- invent products or services not approved in tenant data
- invent prices or totals
- mark any order as paid
- override merchant review when uncertainty exists
- mutate source-of-truth business records without explicit workflow and permission

### 15.3 AI Output Handling
All AI outputs should be treated as:
- candidate extraction
- candidate response
- candidate classification

They must pass deterministic validation before becoming system records where correctness matters.

---

## 16. QR Rules
QR is not an afterthought. It is a first-class entry channel in Phase 1.

Each QR code must:
- belong to a tenant
- have a clear destination type
- support safe routing
- allow analytics collection
- allow regeneration/deactivation when needed

Supported QR destinations in Phase 1:
- catalog page
- service page
- smart landing page
- WhatsApp deep link

---

## 17. WhatsApp Rules
WhatsApp in Phase 1 is primarily used for:
- AI-grounded replies
- inquiry handling
- draft order/request capture

Rules:
- inbound messages must be persisted before deeper processing
- webhook handling must be fast and resilient
- heavy downstream logic must run asynchronously where possible
- outbound replies should be traceable
- uncertain draft extraction must go to review rather than silent assumption

---

## 18. Subscription and Customization Rules
The same platform must serve multiple business levels and plans.

The architecture must support feature gating by subscription tier without rewriting core logic.

Examples of tenant-configurable behavior:
- catalog visibility
- available public channels
- AI reply style constraints
- review requirements before draft acceptance
- quotas and limits

---

## 19. Documentation Rules
Every major module must eventually have:
- purpose
- scope
- entities
- flows
- API surface
- validation rules
- security notes
- observability notes
- test strategy

Current documentation priority order:
1. AGENTS.md
2. PROJECT_OVERVIEW.md
3. ARCHITECTURE.md
4. MODULE_01_CATALOG_ADMIN_QR.md
5. DATABASE_DESIGN_PHASE_1.md
6. API_CONTRACTS_PHASE_1.md

### 19.1 Postman Enforcement (Strict)
- EVERY endpoint MUST be added to Postman.
- Each endpoint entry MUST include:
	- request example
	- response example
- Endpoint updates must be reflected in Postman in the same delivery cycle.
- Final implementation output MUST include: `Postman Updated ✅`.
- If Postman is not updated for endpoint changes, the task is considered FAILED.

---

## 20. Definition of Done
No feature is complete unless it includes, where relevant:
- implementation
- validation
- authorization
- tenant isolation checks
- tests
- failure-path handling
- logging/audit considerations
- documentation update
- UI completion if applicable
- operational readiness considerations

Definition of Done upgrade requirements (mandatory for delivery acceptance):
- no errors
- routes registered
- Postman updated
- performance considered
- indexing considered

---

## 21. Immediate Execution Plan
The next planning and implementation steps should follow this order:
1. finalize project memory and reference documents
2. finalize Phase 1 architecture
3. finalize Phase 1 data model
4. finalize API contracts
5. implement tenant/auth foundation
6. implement catalog and service knowledge foundations
7. implement public pages and QR
8. implement WhatsApp intake and AI reply foundation
9. implement draft order/request review flow
10. harden for production

---

## 22. What Future Agents Must Remember
Any future AI agent working on this project must preserve these truths:
- this is a multi-tenant platform, not a single-store app
- the system must work for products and services
- the merchant supplies their own catalog or knowledge base
- QR is part of the core product
- WhatsApp is part of the core product
- financial correctness is more important than automation speed
- AI is bounded and validated, never authoritative for money
- Phase 1 priority is catalog + admin + QR first

---

## 23. Working Style for Future Project Sessions
When continuing this project in any new conversation:
- start from these documents as source of truth
- avoid re-inventing architecture unless a strong reason exists
- keep decisions explicit and traceable
- prefer structured incremental delivery
- optimize for a real production path, not demo-only shortcuts

This document is the standing project-memory baseline for all future planning and implementation.

