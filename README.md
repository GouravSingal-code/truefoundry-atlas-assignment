# token-router-proxy

Token-based LLM router proxy (FastAPI) with TrueFoundry/EKS deploy manifests

## Architecture

![Architecture](architecture.png)

---

## Step 0 — Build the cluster ([`opentofu-aws/`](opentofu-aws/))

**Is this needed? Yes.** Before anything else can run, we need a place to run it.
The `opentofu-aws/` folder is the code that builds that place: an AWS Kubernetes
cluster (EKS) with TrueFoundry installed on it. The proxy service and all the
gateway config (budgets, guardrails, routing) live *on top of* this cluster.
You run this once to set things up.

It is written in **OpenTofu** (an open, free version of Terraform). You describe
what you want in files, and OpenTofu creates it in AWS for you.

**In simple words, here is what it does:**

1. **Makes a private network in AWS** — a VPC with subnets, so the cluster has its
   own isolated space to run in.
2. **Creates the EKS cluster** — this is the actual Kubernetes cluster
   (`atlas-cluster`) in the AWS region `ap-south-1`.
3. **Adds the pieces a cluster needs** — disk storage (EBS/EFS), a load balancer to
   send traffic to apps, and Karpenter to add or remove servers automatically when
   load goes up or down.
4. **Turns on TrueFoundry platform features** — blob storage, a container registry
   (to hold app images), and parameter store.
5. **Installs TrueFoundry onto the cluster** — connects it back to the TrueFoundry
   control plane (`slayzsloth.truefoundry.cloud`) so you can deploy and manage apps
   from the dashboard.

It is also **safe to re-run.** When it runs, it first checks if the cluster already
exists — if it does, it skips creating it again (see
`truefoundry-cluster.stdout`: *"Cluster already exists and is provisioned.
Skipping creation."*).

> The cluster settings (region, network ranges, version) come from `config.json`
> and `terraform.tfvars`. Both hold secrets, so they are gitignored and never
> pushed.

**How to run it (one time):**

```bash
cd opentofu-aws
tofu init      # download the modules
tofu plan      # preview what will be created
tofu apply     # actually build the cluster
```

After this finishes, the cluster is ready and you can deploy the proxy
([`token-proxy/`](token-proxy/)) and apply the gateway config below.

---

## Atlas Requirements & How We Solve Them

Every solution below is **config on the TrueFoundry AI Gateway**, not application
code. Requests flow through the gateway carrying metadata (`tenant_id`, `tier`,
`token_bucket`, `user`), and the YAML manifests in this repo act on that metadata.

### 1. CTO — Hard cost ceilings per tenant

> *"One tenant's intern burned $4,200 of OpenAI credit in six hours. The CFO wants
> hard ceilings per customer. We have 22 tenants with very different usage patterns."*

**Solved by:** [`budget-rules.yaml`](budget-rules.yaml) (+ tier VAs
[`va-enterprise.yaml`](va-enterprise.yaml), [`va-growth.yaml`](va-growth.yaml),
[`va-starter.yaml`](va-starter.yaml))

A `gateway-budget-config` enforces **per-tenant daily cost limits**, keyed by
`budget_applies_per: metadata.tenant_id`, so each of the 22 tenants gets its own
ceiling rather than a shared pool. Limits are tiered to match different usage
patterns:

| Tier       | Daily limit | Matches on        |
| ---------- | ----------- | ----------------- |
| enterprise | $500/day    | `metadata.tier`   |
| growth     | $100/day    | `metadata.tier`   |
| starter    | $20/day     | `metadata.tier`   |
| untagged   | $10/day     | fallback (catch-all) |

- `audit_mode: false` → limits are **hard-enforced** (requests are blocked at the
  ceiling), not just observed. This is what stops the runaway intern loop.
- Alerts fire to on-call email at **80% / 95% / 100%** before the cap is hit.
- The catch-all `fallback-untagged-daily` rule means a new/untagged tenant can
  never run unbounded.

### 2. CEO — PHI redaction with auditor evidence, for ONE customer only

> *"Our healthcare insurer (22% of ARR) needs SOC 2 proof that PHI doesn't leak into
> OpenAI's logs. None of our other 21 customers care — and the ones who tested
> redaction complained about latency."*

**Solved by:** [`guardrails-policy.yaml`](guardrails-policy.yaml) +
[`phi-guardrail-group.yaml`](phi-guardrail-group.yaml) +
[`healthcare-insurer-va.yaml`](healthcare-insurer-va.yaml)

A `gateway-guardrails-config` applies a PHI-redaction guardrail
(`tfy-pii`, `operation: mutate`, `enforcing_strategy: enforce`, all PII
categories) **scoped to a single subject** — `virtualaccount:healthcare-insurer-va`.
Two design choices map directly to the requirement:

- **Only the healthcare tenant is affected.** The `when.subjects` condition limits
  the policy to that one VA, so the other 21 customers see zero behavior change.
- **Latency is minimized.** `llm_input_guardrails` runs PHI redaction on the way
  *in* (before data reaches OpenAI), while `llm_output_guardrails: []` is left
  empty — we don't double-scan responses, removing the sluggishness the sandbox
  testers complained about.
- **Auditor evidence:** redaction runs as an enforced gateway step, and the
  healthcare VA is tagged `compliance: soc2`, so every redaction is logged and
  attributable for the SOC 2 auditor.

### 3. CISO — No tenant data persisted on vendor infra; logs land in *their* S3

> *"Zero tolerance for prompt/response data — even sanitized — on a vendor's
> infrastructure. Logs land in our S3 with our retention policy, or we don't renew.
> The other 21 are fine with TrueFoundry storage."*

**Solved by:** [`two-va-routing.yaml`](two-va-routing.yaml)

A `gateway-data-routing-config` splits trace/log storage by tenant:

- Traces created by `virtualaccount:healthcare-insurer-va` route to
  **`storage.type: customer-managed`** — the customer's own S3 bucket
  (`storage_integration_fqn`), with a **90-day retention** policy they control.
  Nothing from this tenant persists on TrueFoundry's control plane.
- The `default` destination stays `controlplane-managed`, so the other 21
  customers are unchanged.

This gives the CISO exactly what he asked for without altering anyone else's setup.

### 4. Head of Product — Token-based model routing, **no service deploy**

> *"Send any input over ~8K tokens to Claude Opus, keep GPT-4o for the rest. The
> deploy queue is four weeks deep — I want this without a service deploy."*

**Solved by:** [`atlas-virtual-model.yaml`](atlas-virtual-model.yaml) + the proxy
([`main.py`](token-proxy/main.py))

▶️ **Demo video:** https://youtu.be/TpckrfeM_Ww?si=hwCdTnEq4QI7mfT3

The proxy counts input tokens and tags each request with an `x-tfy-metadata`
`token_bucket` of `small` or `large`. The **virtual model** then does
weight-based routing on that metadata, entirely in gateway config:

| token_bucket | Routed to                   |
| ------------ | --------------------------- |
| `small`      | `openai/gpt-4o`             |
| `large`      | `anthropic/claude-opus-4-5` |

- **No four-week deploy:** routing targets live in the virtual model manifest, and
  the cutover threshold is the `SMALL_THRESHOLD` env var (currently `4096`; set to
  `8192` for the ~8K rule). Changing the split is a config change, not an
  application rebuild — the deploy queue never enters the picture.

### 5. Revenue Ops — Per-tenant cost report + per-end-user usage for BigCorp

> *"CFO needs a per-tenant cost report for the last 90 days. BigCorp wants
> per-end-user usage inside their org. Today we have zero visibility at either level."*

**Solved by:** per-request metadata + [`bigcorp-va.yaml`](bigcorp-va.yaml)

Because every request carries `metadata.tenant_id` (the same key the budgets use)
and a per-user identifier, the gateway's usage/cost metrics can be grouped at two
levels:

- **Per-tenant cost (90 days):** aggregate gateway cost metrics by
  `metadata.tenant_id` — this directly produces the CFO's chargeback report and
  exposes the two outlier tenants billing flat per-seat.
- **Per-end-user for BigCorp:** [`bigcorp-va.yaml`](bigcorp-va.yaml) is BigCorp's
  dedicated virtual account (tagged `tier: enterprise`); filtering its traffic by
  the `user` metadata dimension surfaces power users inside their org.

---

## Manifest index

| File | Purpose |
| ---- | ------- |
| [`service.yaml`](token-proxy/service.yaml) / [`deploy.py`](token-proxy/deploy.py) | Deploy the proxy service |
| [`atlas-virtual-model.yaml`](atlas-virtual-model.yaml) | Token-based model routing (req #4) |
| [`budget-rules.yaml`](budget-rules.yaml) | Per-tenant cost ceilings (req #1) |
| [`guardrails-policy.yaml`](guardrails-policy.yaml) / [`phi-guardrail-group.yaml`](phi-guardrail-group.yaml) | PHI redaction for one tenant (req #2) |
| [`two-va-routing.yaml`](two-va-routing.yaml) | Customer-managed log storage (req #3) |
| [`va-enterprise.yaml`](va-enterprise.yaml) / [`va-growth.yaml`](va-growth.yaml) / [`va-starter.yaml`](va-starter.yaml) | Tiered virtual accounts |
| [`healthcare-insurer-va.yaml`](healthcare-insurer-va.yaml) / [`bigcorp-va.yaml`](bigcorp-va.yaml) | Customer-specific virtual accounts |
| [`atlas-cluster.yaml`](atlas-cluster.yaml) / [`cluster.yaml`](cluster.yaml) | EKS cluster config |
