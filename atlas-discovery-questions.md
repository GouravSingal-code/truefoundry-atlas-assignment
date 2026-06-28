# Atlas — Discovery Questions (before we build)

**The constraint that shapes everything:** Atlas's engineering team is fully booked.
We get **exactly one 30-minute meeting** to request app-side changes (set a base
URL, send headers, add metadata). Everything else must be solved through
**TrueFoundry Gateway configuration** — no new services, no SDKs, no app refactors.

So the questions are ranked by a simple rule:

1. **P0 — Foundational / app-side:** answers that decide what we spend the one
   30-min meeting on. If we get these wrong, nothing else works.
2. **P1 — Behavior & compliance:** design decisions that change the config and
   carry renewal/audit risk.
3. **P2 — Config values:** numbers and toggles we can default sensibly and confirm
   later.

---

## P0 — Foundational (must answer; mostly the one app-side meeting)

These are the asks for the 30-minute meeting. The Gateway **routes, budgets, and
reports on metadata it receives** — it does not infer tenant, user, or token size
on its own. So the app must send the right signals.

1. **Per-request identity — will you send `tenant_id` (and `user_id`) as metadata
   on every API call, or should we issue a separate API key per tenant?**
   *Why it's #1:* every other feature (per-tenant budgets, per-tenant log routing,
   per-tenant + per-user cost reports) keys off this. No tenant identity → nothing
   downstream works.

2. **Token-size flag — can your app count tokens before the call and pass a flag
   like `x-tfy-metadata: {"size": "large"}` when input exceeds the threshold?**
   *Why:* the gateway routes on metadata; **it does not count tokens itself.** This
   is the single app-side change that makes "big → Claude, small → GPT-4o" work
   with zero service deploy. If they can't set this, req #4 changes shape.

3. **Stable user IDs for BigCorp — do end-users have stable unique IDs in your
   system, or only per-session IDs?**
   *Why:* BigCorp's per-end-user "power user" report is only possible with a stable
   `user_id`. Session-only IDs mean we can't attribute usage to a person.

4. **Tenant → tier mapping — how many tiers are there, and which of the 22 tenants
   is Enterprise / Growth / Starter?** *(added)*
   *Why:* budgets are enforced by a `tier` metadata tag. We need the mapping to set
   the right ceiling for each tenant.

---

## P1 — Behavior & compliance (design decisions, renewal/audit risk)

5. **Budget overflow — when a tenant hits its ceiling, do we hard-block requests,
   or allow overage and just alert?**
   *Why:* this is the `audit_mode` switch. The CTO asked for "hard ceilings," but
   blocking a paying customer mid-contract is a business call — confirm explicitly.

6. **PHI redaction scope — does it apply to inputs (what the user sends), outputs
   (model response), or both?**
   *Why:* input-only is enough to keep PHI out of OpenAI's logs and is far faster
   (directly addresses the "sluggish" sandbox complaint). Both = safer but slower.
   This trade-off needs the customer's call.

7. **PHI on detection — block the request entirely, or redact and continue?**
   *Why:* redact-and-continue keeps the assistant usable; block is stricter. Drives
   the guardrail's enforcing strategy.

8. **Healthcare logs — should ALL of their traces go to their S3, or only traces
   where PHI was detected? What retention period do they require? And do they
   already have the S3 bucket + cross-account IAM role ready?** *(readiness added)*
   *Why:* the CISO said "zero tolerance for ANY prompt/response data on a vendor,"
   which points to ALL traces → their S3. Confirm scope, retention, and that the
   bucket/role exist so we can wire `storage_integration_fqn`.

---

## P2 — Config values (sensible defaults exist; just confirm)

9. **Exact dollar limits per tier — Enterprise, Growth, Starter?**
   *(We can propose e.g. $500 / $100 / $20 per day and let them adjust.)*

10. **Exact token threshold for Claude Opus — is it a flat ~8K, or does it vary by
    tier?**

11. **Which PHI/PII categories must be caught — names, SSNs, diagnosis codes,
    policy numbers, DOB?** *(Default: catch all PII categories, then narrow.)*

12. **Budget reset — calendar month, or each customer's contract start date?**

13. **Alert routing — who gets the budget alert (your team, the customer, or both),
    and via Slack, email, or Teams?**

---

## Cross-cutting (don't forget)

14. **Anthropic access — do you have a Claude/Anthropic provider account, or only
    OpenAI today?** *(added)* Routing to Opus needs Anthropic credentials wired
    into the gateway.

15. **Routing fallback — if Claude Opus is unavailable, should large requests fall
    back to GPT-4o, or fail?** *(added)* Defines routing resilience.

---

## What to actually ask for in the 30-minute meeting

Keep the scarce meeting tight. Only three app-side asks are required:

- **Set the base URL** to the TrueFoundry gateway (`https://gateway.truefoundry.ai`).
- **Send identity metadata** on every request: `tenant_id`, `user_id`, `tier`.
- **Send the token-size flag** (`x-tfy-metadata: {"size": "large"|"small"}`) based
  on the app's own token count.

Everything else — budgets, PHI redaction, customer-managed S3 logging, model
routing, cost reports — we configure on the Gateway with **no further app work.**
