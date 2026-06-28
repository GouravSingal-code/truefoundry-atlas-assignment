# Architecture — Proposed Changes

## Self-service dedicated TrueFoundry cluster

**Today:** standing up the platform means provisioning an AWS EKS cluster via IaC
(OpenTofu/Terraform) and then installing TrueFoundry on it — heavy setup that
requires AWS/Kubernetes expertise and ongoing cluster operations.

**Proposed:** let users spin up a dedicated, fully managed TrueFoundry cluster on
demand, directly from the TrueFoundry UI. TrueFoundry owns the cluster lifecycle
(creation, upgrades, scaling, teardown).

**Why it's better:** self-service from the platform, no EKS expertise or Terraform
to maintain, faster onboarding, and dedicated isolation without the setup cost.
