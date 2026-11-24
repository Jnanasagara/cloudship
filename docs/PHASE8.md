# Phase 8: reproducibility, proof and interview readiness

November 24, 2026 checkpoint. The code and operational documents describe the
system actually demonstrated, including its failure behavior and limitations.

## Deliverables

- [README](../README.md): architecture, prerequisites, local app/container/tests,
  Terraform, GitHub variables/OIDC, deployment, kind, cost and cleanup instructions.
- [Architecture](ARCHITECTURE.md): identities, traffic/data paths, local/cloud
  separation, release/recovery invariants and single-instance limits.
- [Runbook](RUNBOOK.md): CI/GHCR/OIDC/SSM, unhealthy release/recovery, missing logs,
  alarms, networking, Terraform, local Kubernetes and cost/lifecycle procedures.
- [Interview questions](INTERVIEW_QA.md): 20 concise questions and truthful answers.
- [Evidence checklist](EVIDENCE_CHECKLIST.md): real test/API/CLI/GitHub observations.
- Phase records cover [infrastructure](PHASE3_VERIFICATION.md), [CI/CD](PHASE4.md),
  [rollback](PHASE5.md), [monitoring](PHASE6.md), and [kind](PHASE7.md).

## Final verification

- Full isolated Linux suite: **40 passed**. It executes the actual Bash/jq/state
  logic with stateful external boundaries, plus application and SSM transport tests.
- Windows Python suite: **17 passed, 23 intentionally skipped** privileged Linux
  cases. The skipped cases passed separately in Linux locally and under CI sudo.
- Terraform format and validation passed; the controlled plan/apply lifecycle and
  runtime IAM/network/tag/bootstrap checks were already demonstrated in Phase 3.
- Kubernetes manifests passed server-side validation and actual local rollout.
- A fresh independent code review found recovery/privacy issues, which were first
  reproduced by failing tests, fixed, and re-reviewed with no remaining findings.
- Fresh cloud CI tests and publication passed; actual AWS OIDC/SSM deployment,
  rejected unhealthy release, exact previous-image recovery and healthy update
  were verified in the linked workflow runs.
- Actual CloudWatch events/metrics/alarms and local kind operations were observed.
- Documentation links and non-ignored source were scanned for private AWS IDs,
  client IPs and common credential patterns; real settings/state/artifacts stay ignored.
- Commits and pushes use the user's pre-existing Git identity. No assistant
  authorship or coauthor trailer was added.
- Approved teardown destroyed all 20 project-managed AWS resources; independent
  AWS absence checks and zero managed state passed. Local kind was removed after
  its demonstrated rollout/scaling/recovery. See [cleanup](../CLEANUP.md).

## Authentic evidence

The record uses genuine GitHub workflow URLs and sanitized actual command/API
observations. Raw logs/state remain private in ignored artifacts. No screenshots
were fabricated or reconstructed. The current chat's browser capture was unavailable;
the evidence links lead to the real runs rather than a manufactured dashboard image.
If adding screenshots later, capture actual pages/CLI output and redact private
account/resource identifiers, client addresses and tokens.

GitHub logs may expire and cloud logs are removed by final approved cleanup.
Retain private source evidence as needed; version-controlled summaries state exact
observations and limits instead of claiming the service remains hosted forever.
