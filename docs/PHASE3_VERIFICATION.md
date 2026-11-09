# Phase 3 verification record

Verified on **2026-11-09**, with the final AWS checks recorded at
**11:24:42 UTC**. These results came from actual Terraform execution, AWS API
responses and an SSM Run Command; they are not inferred from configuration alone.

## Results

| Check | Observed result |
| --- | --- |
| Terraform initialization | Locked provider initialization succeeded |
| Formatting and validation | Passed |
| Application regression tests | 8 passed; dependency compatibility check clean |
| Account safeguard | Correct workload account accepted; mismatched account rejected |
| Initial saved plan | 20 additions, no changes or deletions |
| Approved apply | 20 added, 0 changed, 0 destroyed |
| EC2 | Running `t3.micro` in Sydney; system and instance status checks OK |
| Root storage | 8 GiB gp3, encrypted, 3,000 IOPS, 125 MiB/s; delete on termination |
| Metadata and CPU credits | IMDSv2 required; CPU credits in Standard mode |
| Ingress | Only configured client IPv4 `/32` on TCP 80; no SSH or IPv6 ingress |
| Egress and routing | TCP 443 outbound; dedicated subnet has an active internet-gateway route |
| Resource tags | Project, Environment and ManagedBy verified on supported resources |
| Host IAM | EC2 trust and profile verified; SSM core attached; logs limited to application streams |
| Systems Manager | Online; agent version 3.3.5700.0 |
| Bootstrap | cloud-init done; completion marker found; directory permissions/settings verified |
| Docker | Enabled and active; daemon version 25.0.18, CLI version 25.0.14 |
| GitHub OIDC configuration | Issuer/audience, exact immutable repository/main trust and SSM policy verified through IAM APIs |
| CloudWatch Logs | Application log group exists with seven-day retention |
| Metric alarms | CPUUtilization and StatusCheckFailed both reported OK; dimensions and thresholds verified |
| Post-apply plan | No changes; detailed exit code 0 |
| Git privacy checks | Real account ID/client CIDR absent from non-ignored files; variables, state, saved plans and raw logs ignored |

Selected actual command output:

```text
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.
status: done
Docker version 25.0.14, build 0bab007
Docker server: 25.0.18
CloudShip bootstrap complete
PHASE3_HOST_VERIFIED
No changes. Your infrastructure matches the configuration.
```

The SSM verification invocation returned **Success** with response code **0**.
Terraform outputs for instance ID, public IP, log group and deployment role ARN
are available locally; retrieve them with `terraform -chdir=terraform output`.
Raw identifiers and the client IP are intentionally excluded from this record.

## Credit review and current lifecycle

The management-account Credits page showed **$120 active and unused**, expiring
November 8, 2027, before provisioning. EC2, VPC, CloudWatch and Systems Manager
were listed as applicable services, and credit sharing was activated for the
workload account. This establishes configured service coverage, not a guaranteed
zero-cash invoice. Actual credit deductions and applicable taxes may appear later.

The instance is **running** for the next deployment phase. Compute and its public
IPv4 address together cost approximately **$0.0182/hour** before credits, plus
storage, monitoring and any chargeable traffic. The $5 budget is an alert, not a
cap. Follow the approved-cleanup procedure in [the Phase 3 guide](PHASE3.md) when
finished; stopping the instance alone does not delete storage or monitoring.

## What this does not establish

- No application container has been deployed to EC2 yet; an HTTP response is not
  expected until Phase 4.
- The GitHub workflow has not yet exchanged an OIDC token or deployed through
  the restricted role. Phase 3 verified the created IAM configuration.
- No application log events or automated rollback have been demonstrated in AWS.
- Both alarms being OK is evidence about instance metrics, not application health.
- No high availability, zero downtime or public HTTPS claim is made.
- Kubernetes remains a separate future local kind exercise.
- Cleanup instructions are documented; actual teardown is not yet performed.
