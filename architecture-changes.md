# Architecture — Proposed Changes

Forward-looking improvements to reduce setup effort and operational burden.

## Self-service dedicated TrueFoundry cluster

### Today

Standing up the platform requires provisioning an AWS EKS cluster — VPC and
subnets, node groups, autoscaling, storage, ingress, and the other add-ons — using
infrastructure-as-code (OpenTofu/Terraform), and then installing TrueFoundry on top
of it. This is operationally heavy:

- Someone needs AWS and Kubernetes expertise to create the cluster.
- The IaC must be maintained, and the cluster lifecycle (upgrades, scaling,
  add-ons, security patches) becomes an ongoing responsibility.
- Onboarding is slow, because the cluster has to exist before any workload runs.

### Proposed

Offer a **dedicated, fully managed TrueFoundry cluster that a user can spin up on
demand directly from the TrueFoundry platform** — no hand-rolled EKS cluster and no
infrastructure to manage.

- The user provisions a dedicated cluster from the TrueFoundry UI in a few clicks.
- TrueFoundry owns the underlying cluster lifecycle: creation, upgrades, scaling,
  add-ons, and teardown.
- Clusters can be spun up or down at any time, so capacity matches need.

### Why this is better

- **Self-service:** provision directly on the TrueFoundry page; no AWS console or
  Terraform required.
- **No EKS expertise needed:** customers don't have to know Kubernetes to get
  started.
- **Faster onboarding:** a working environment is available immediately, instead of
  waiting on an infrastructure build.
- **Less to maintain:** no IaC to keep current and no cluster operations to own —
  TrueFoundry manages it.
- **Dedicated and isolated:** each cluster is dedicated to the user, keeping the
  isolation benefits of a single-tenant cluster without the setup cost.

### Trade-offs to confirm

- Cloud account ownership and billing model (TrueFoundry-hosted vs. customer
  account) and any data-residency requirements.
- Network and VPC peering needs for customers that must reach private resources.
- Cost controls so on-demand clusters don't run idle.
