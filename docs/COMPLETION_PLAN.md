# Remaining CloudShip phases

> Execution: implement inline, verify each stage, then obtain a fresh final code
> review. User authorized implementation, commits and pushes on November 24, 2026.

**Goal:** Complete and demonstrate Phases 5–8 of the local master project brief.

**Architecture:** Retain Terraform's existing Sydney EC2, exact-repository/main
OIDC trust, public GHCR and SSM delivery. Bash manages current/previous release
records in one atomically replaced JSON file. Kubernetes remains local in kind.

**Spec:** `CloudShip_Codex_Project_Brief.md` (local, intentionally ignored).

## Constraints and rulings

- No assistant authorship, coauthor trailers or contributor attribution.
- No extra AWS services, unrestricted ingress, SSH, static AWS keys or EKS.
- Work in the existing checkout; preserve its local Terraform state and inputs.
  Use a `codex/` implementation branch and explicitly authorized main integration.
- Existing restart, eligible running costs and client /32 update are authorized.
  Final deletion of AWS infrastructure remains a separately reviewed destructive
  boundary; prepare the concrete teardown only after all cloud evidence is saved.
- Complete implementation and verification without routine permission pauses.
- Keep raw AWS identifiers, client IPs, state, credentials and logs out of Git.

## Review focus

1. A failed candidate must leave or restore the last actually healthy release.
2. Initial adoption of the existing Phase 4 container must not lose recovery data.
3. Rollback success must still produce a failed GitHub deployment result.
4. A logging-driver failure must not silently destroy the previous logging setup.
5. Manual unhealthy input must never activate from an ordinary push.

## Task 1: Rollback and its executable tests

Files: `scripts/deploy.sh`, `scripts/deploy_ssm.py`, workflow, deployment tests and
fixtures. Preserve `IMAGE_REF`, `APP_VERSION`, existing GitHub repository variables
and SSM permissions. Add an explicit manual unhealthy mode, defaulting to healthy.

- [ ] Write Linux Bash integration tests against a stateful fake Docker boundary;
  exercise the real script, jq, state files, exits and recovery behavior.
- [ ] Observe missing rollback tests fail against Phase 4.
- [ ] Implement current/previous image+version+logging records, healthy adoption,
  atomic state replacement, pull-before-stop, failed-start/health recovery, clear
  first-deploy and failed-recovery results; add Python transport validation tests.
- [ ] Verify full Python suite and Linux deployment suite, syntax and privacy.
- [ ] Push tested code, verify a healthy release, publish a distinct candidate
  while automatic deployment is paused, run the manual unhealthy candidate and
  prove old version restored with failed workflow; restore normal deployment.

## Task 2: Actual CloudWatch application logs

Files: deployment logging configuration, Phase 6 evidence and runbook notes. Use
the existing `/etc/cloudship.env`, log group, seven-day retention and EC2 IAM role.

- [ ] Preserve the previous release's logging configuration during rollback.
- [ ] Enable Docker awslogs only with validated existing host configuration.
- [ ] Verify new application log events through CloudWatch APIs, existing EC2
  metrics, alarm dimensions/thresholds and tags; do not generate heavy CPU load.
- [ ] Record actual evidence and observed limitations.

## Task 3: Local Kubernetes

Files: `kubernetes/deployment.yaml`, `service.yaml`, Phase 7 reproduction notes.

- [ ] Install checksum-verified kind locally if missing; inspect kubectl compatibility.
- [ ] Create only named local cluster `cloudship`; use a verified image digest,
  two replicas, resource bounds, /health probes, non-root restrictions and ClusterIP.
- [ ] Verify rollout, localhost port-forward health/version, logs, scaling, a
  distinct-version rolling update and recovery after deleting a test Pod.
- [ ] Remove the project-created local cluster after evidence capture.

## Task 4: Documentation, review and lifecycle

Files: README, architecture, runbook, evidence checklist, interview Q&A, phase
verification records and reproducible cleanup instructions.

- [ ] Update all phase statuses only from actual results; document clone/setup,
  runtime/development locks, AWS identities, operations, costs and local kind.
- [ ] Run fmt/validate, full tests, Linux tests, manifest checks, diff/privacy and
  documentation link checks. Obtain the required fresh final code review.
- [ ] Commit/push with the user's configured Git identity and verify GitHub runs.
- [ ] Stop idle project compute after cloud demonstrations, prepare and review
  a fresh project-owned teardown, and perform destructive cleanup only with approval.

## Verification commands

- Windows: `.\.venv\Scripts\python.exe -m pytest -q`.
- Linux deployment tests: run the root-required Bash suite in a local Linux test
  container and in the disposable GitHub runner; Windows skips only that suite.
- Terraform: `fmt -check`, `validate`; never apply an unrelated refreshed AMI change.
- Live: GitHub job logs, SSM results, HTTP version, CloudWatch events and kubectl
  output, all tied to the tested commit rather than inferred from source text.
