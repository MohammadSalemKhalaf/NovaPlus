# AI RULES (STRICT)

This is a production SaaS system.

YOU MUST:
- Follow AGENTS.md strictly
- Follow ARCHITECTURE.md strictly
- Follow DATABASE_DESIGN_PHASE_1.md strictly
- Follow API_CONTRACTS_PHASE_1.md strictly

DO NOT:
- Invent any architecture
- Skip validation
- Skip authorization
- Ignore tenant isolation
- Generate financial logic using AI

MULTI-TENANT:
- Every query MUST include tenant_id
- Never expose cross-tenant data

SECURITY:
- Validate all inputs
- Never trust client input
- Always use middleware for tenant

CODE STYLE:
- Controllers must be thin
- Business logic in services
- Use Form Requests for validation

AI LIMITS:
- AI can parse text
- AI CANNOT generate prices or totals

FAILURE:
If unsure → ask, do not guess