# Atlas — Discovery Questions

A prioritised set of questions to resolve with Atlas before implementation. The
goal is to lock down the few decisions that determine the architecture, then
confirm the remaining configuration values.

## Guiding constraint

Atlas's engineering team is fully booked. We have a single 30-minute window to
request application-side changes (base URL, request headers, request metadata).
Everything else is delivered through TrueFoundry Gateway configuration — no new
services and no application refactors.

Because the application-side window is the scarce resource, the questions are
prioritised accordingly:

- **P0 — Foundational:** answers that determine the application-side asks and the
  overall design. Unresolved, these block implementation.
- **P1 — Behaviour and compliance:** decisions that change configuration and carry
  renewal or audit risk.
- **P2 — Configuration values:** parameters with safe defaults that can be
  confirmed without blocking progress.

---

## P0 — Foundational

The Gateway routes, enforces budgets, and reports on the metadata it receives; it
does not infer tenant, user, or token size on its own. These questions define what
the application must send.

1. **Request identity.** Will each request carry `tenant_id` (and `user_id`) as
   metadata, or should we provision a separate API key per tenant? Per-tenant
   budgets, per-tenant log routing, and per-tenant and per-user reporting all
   depend on this identity being present.

2. **Token-size signal.** Can the application measure input size before the call
   and pass a metadata flag (for example `x-tfy-metadata: {"size": "large"}`) when
   it exceeds the threshold? The Gateway routes on this metadata rather than
   counting tokens itself; this single change enables model routing with no service
   deploy.

3. **End-user identifiers.** For BigCorp's per-user reporting, do end-users have
   stable unique identifiers, or only per-session identifiers? Stable identifiers
   are required to attribute usage to individuals.

4. **Tenant-to-tier mapping.** How many tiers exist, and which of the 22 tenants
   belongs to each? Budgets are enforced by a `tier` metadata tag, so this mapping
   is needed to apply the correct ceiling per tenant.

---

## P1 — Behaviour and compliance

5. **Budget enforcement.** When a tenant reaches its ceiling, should requests be
   hard-blocked, or allowed to overage with an alert? This selects between enforced
   and audit modes and is ultimately a commercial decision.

6. **Redaction scope.** Should PHI redaction apply to inputs, outputs, or both?
   Input-only redaction keeps PHI out of the provider's logs at the lowest latency;
   covering both is stricter but slower.

7. **Action on detection.** When PHI is detected, should the request be blocked, or
   redacted and allowed to continue?

8. **Healthcare log handling.** Should all of the healthcare tenant's traces route
   to their S3 bucket, or only those where PHI is detected? What retention period
   is required, and is the destination bucket and cross-account IAM role already
   provisioned?

---

## P2 — Configuration values

9. **Tier limits.** What are the daily cost ceilings for Enterprise, Growth, and
   Starter?

10. **Routing threshold.** What is the exact token threshold for routing to Claude
    Opus, and does it vary by tier?

11. **PII categories.** Which categories must be detected (names, SSNs, diagnosis
    codes, policy numbers, dates of birth)?

12. **Budget reset cadence.** Do budgets reset on the calendar month or on each
    tenant's contract start date?

13. **Alert routing.** Who receives budget alerts (Atlas, the customer, or both),
    and through which channel (Slack, email, or Teams)?

---

## Additional considerations

14. **Provider availability.** Is an Anthropic (Claude) provider account available,
    or is the current setup OpenAI-only? Routing to Opus requires Anthropic
    credentials configured in the Gateway.

15. **Routing fallback.** If Claude Opus is unavailable, should large requests fall
    back to GPT-4o, or fail?

---

## Application-side requests for the 30-minute window

The implementation requires only three application-side changes; everything else is
Gateway configuration.

1. Point the application's base URL at the TrueFoundry Gateway
   (`https://gateway.truefoundry.ai`).
2. Include identity metadata on every request: `tenant_id`, `user_id`, and `tier`.
3. Include the token-size flag (`x-tfy-metadata: {"size": "large" | "small"}`)
   based on the application's own input measurement.
