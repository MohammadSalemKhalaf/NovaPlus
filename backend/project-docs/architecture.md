# ARCHITECTURE.md

## 1. Architecture Overview

The AI Commerce Platform is designed as a **multi-tenant modular monolith** in Phase 1, with clear boundaries to evolve into microservices when needed.

The system must:
- Support thousands of tenants
- Isolate tenant data strictly
- Provide real-time and async processing
- Integrate external channels (WhatsApp)
- Use AI safely with strict boundaries

---

## 2. High-Level System Components

### Core Layers

1. **Client Layer**
   - Admin Dashboard (Next.js)
   - Public Pages (Catalog / Service / QR Landing)
   - WhatsApp Client (external)

2. **API Layer (Backend - Laravel)**
   - Public APIs
   - Admin APIs
   - Webhooks

3. **Application Layer (Modules)**
   - Tenant Module
   - Auth Module
   - Catalog Module
   - Service Knowledge Module
   - QR Module
   - Messaging Module
   - AI Orchestration Module
   - Draft Order Module
   - Audit Module

4. **Infrastructure Layer**
   - PostgreSQL (main DB)
   - Redis (cache + queue)
   - Object Storage (S3)
   - Vector Storage (pgvector)

5. **External Services**
   - WhatsApp Business API
   - OpenAI / LLM provider
   - n8n (automation engine)

---

## 3. Multi-Tenant Architecture

### Tenant Isolation Strategy

Each request must include tenant context:
- tenant_id resolved via:
  - subdomain OR
  - token OR
  - QR OR
  - authenticated session

Rules:
- Every DB query must be scoped by tenant_id
- No cross-tenant joins without explicit system-level permission
- Background jobs must carry tenant context

---

## 4. Module Interaction Diagram (Logical Flow)

### Customer Interaction Flow

Customer → WhatsApp / QR / Web
→ API Gateway
→ Messaging Module
→ AI Module
→ Catalog / Knowledge Retrieval
→ Response OR Draft Order

---

## 5. WhatsApp Integration Flow

1. Customer sends message
2. WhatsApp → Webhook
3. Backend receives message
4. Message stored (inbound_messages)
5. Message sent to queue
6. AI Module processes message
7. Response generated
8. Response sent via WhatsApp API
9. Stored in outbound_messages

### Important Rules
- Webhook must be fast (<1s response)
- Processing async
- Retry-safe

---

## 6. AI + RAG Architecture

### Pipeline

1. Input message
2. Intent classification
3. Retrieve relevant data:
   - products
   - services
   - FAQs
4. Inject context
5. Generate response
6. Optional: extract draft order

### Data Sources
- items (products)
- service_chunks
- FAQs

### Safety Layer
- Validate extracted items against DB
- Reject unknown items
- Confidence scoring

---

## 7. Catalog Architecture

### Structure
- categories (tree)
- items
- item_variants
- item_prices
- item_images

### Rules
- Prices always stored explicitly
- No derived pricing from AI

---

## 8. Service Knowledge Architecture

### Pipeline

1. Upload PDF
2. Parse document
3. Chunk text
4. Embed chunks
5. Store in vector DB
6. Merchant approves content

### Retrieval
- semantic search
- top-k chunks
- injected into prompt

---

## 9. QR Architecture

### QR Entity
- id
- tenant_id
- type
- destination
- token

### Flow
QR scan → API resolve
→ redirect to:
- catalog
- service page
- WhatsApp

---

## 10. Draft Order Architecture

### Flow

1. AI extracts items
2. Validate items
3. Create draft_order
4. Notify merchant
5. Merchant approves

### Structure
- draft_orders
- draft_order_items

---

## 11. Public Pages Architecture

### Routes
- /t/{tenant}
- /t/{tenant}/catalog
- /t/{tenant}/services
- /q/{token}

### Requirements
- mobile-first
- fast load
- CDN assets

---

## 12. Security Architecture

### Layers

1. Authentication
2. Authorization
3. Tenant Isolation
4. Data Validation
5. Webhook Security

### Controls
- JWT / session auth
- role-based access
- signed webhooks
- rate limiting

---

## 13. Performance Architecture

### Strategy

- Cache catalog reads
- Queue AI processing
- Minimize LLM calls
- Use indexing

### Tools
- Redis caching
- DB indexing
- CDN

---

## 14. Observability

### Must Have
- request logs
- error logs
- audit logs
- metrics

### Optional (later)
- tracing

---

## 15. Deployment Architecture

### Environments
- local
- staging
- production

### Requirements
- environment isolation
- secrets management
- backups

---

## 16. Scaling Strategy

### Phase 1
- vertical scaling
- queue workers

### Phase 2+
- service separation
- dedicated AI service
- message service

---

## 17. Failure Handling

### Must Handle
- WhatsApp failures
- AI failures
- DB failures

### Strategy
- retries
- fallback responses
- logging

---

## 18. Key Architecture Decisions

1. Modular monolith first
2. AI bounded by system data
3. Tenant-first design
4. Async processing for heavy tasks
5. QR as first-class entry

---

## 19. Next Step After Architecture

- Database schema
- API contracts
- Module implementation order

---

## 20. Summary

This architecture ensures:
- flexibility for any business type
- scalability
- high accuracy for financial data
- safe AI integration
- production readiness

This document is the technical foundation for Phase 1 implementation.

