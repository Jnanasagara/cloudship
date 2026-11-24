# Evidence and honest completion status

Record observed results, not inferred features. Never publish account IDs, client
IPs, state, credentials, kubeconfig or raw logs. Do not fabricate screenshots.

| Requirement | Status / evidence |
| --- | --- |
| App routes and controlled health failure | Verified in Phase 1/2 tests |
| Non-root Docker runtime and local HTTP | Verified; published image smoke-tested |
| Terraform plan/apply, tags, network/IAM/SSM | Verified — [Phase 3 record](PHASE3_VERIFICATION.md) |
| No SSH; client /32 HTTP; required IMDSv2 | Verified through live AWS APIs |
| CI tests and public GHCR publication | Verified — [Phase 4](PHASE4.md) |
| Actual OIDC/SSM deployment and updated /version | Verified — [first deployment](https://github.com/Jnanasagara/cloudship/actions/runs/45409223571), [update](https://github.com/Jnanasagara/cloudship/actions/runs/45411153351) |
| Failed unit test blocks publishing/deployment | Verified — [intentional failure](https://github.com/Jnanasagara/cloudship/actions/runs/45411167308); healthy service unchanged |
| Real previous-image rollback | Verified distinct B served HTTP 503, A's exact digest/version restored, deployment stayed failed — [Phase 5](PHASE5.md) |
| Actual CloudWatch application events | Verified startup, health and version events — [Phase 6](PHASE6.md) |
| EC2 metrics/alarms | Actual CPU datapoints, both correct-instance alarms OK; retention seven days |
| Two-replica kind workload, probes, service | Verified — [Phase 7](PHASE7.md) |
| Rolling update, scaling, Pod recovery and port-forward | Verified against distinct published versions; actual HTTP and new Pod UID observed |
| kind cleanup | Verified project-created cluster removed, no PVC/PV data, private kubeconfig explicitly scoped |
| Terraform teardown and absence of project cost-bearing resources | Approved 20-resource teardown verified through AWS APIs and zero managed state — [cleanup](../CLEANUP.md) |
| README, architecture, runbook, interview preparation | Complete; local links/privacy checks passed — [final record](PHASE8.md) |

## Capture checklist

- GitHub normal run with all jobs green, matching commit and observed HTTP version.
- Intentional unit failure with downstream jobs skipped.
- Manual unhealthy release with failed deployment, actual rollback decision, old
  digest/version restored and successful external health afterward.
- CloudWatch stream containing real startup/HTTP application messages, retention,
  EC2 metric datapoints and the alarm configuration/instance dimension.
- kind node/version, two ready replicas, service, actual port-forward HTTP, rollout,
  scaling, replacement Pod UID and final cluster removal.
- Reviewed Terraform destroy plan, apply result and AWS absence checks after approval.

Genuine GitHub run URLs and sanitized API/CLI observations are acceptable evidence.
If capturing screenshots, use actual screens, redact private identifiers, and label
dates/context. Workflow logs may expire; retain private originals when appropriate
and record only sanitized summaries in version-controlled documentation.

## Resume claim boundaries

1. **Terraform infrastructure:** provisioning/IAM/network/tags and the controlled
   plan/apply/destroy lifecycle are verified.
2. **GitHub Actions CI/CD:** verified by actual tests, publication, OIDC, SSM and
   version changes, including a failing-test gate.
3. **Rollback, CloudWatch and kind:** all required live/local demonstrations were
   verified and recorded above. The environment was then intentionally removed.

The original resume bullets are supported as completed learning-project work.
Describe kind explicitly as local and the AWS application as single-instance;
do not imply that it remains running after cleanup.

No claim of production HA, zero downtime, public HTTPS, multi-region deployment,
EKS or Kubernetes managing EC2 is supported by this project.
