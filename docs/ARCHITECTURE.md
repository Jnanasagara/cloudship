# Architecture and trust boundaries

## Two separate deployments

The cloud path is GitHub → GHCR → SSM → EC2 Docker. Terraform owns a dedicated
VPC, one public subnet, internet gateway/routes, security group, one encrypted
EC2 root disk/instance, instance IAM/profile, deployment IAM/OIDC, log group and
two metric alarms. No load balancer, NAT, database or managed Kubernetes is used.

The local exercise is public GHCR → kind → a two-replica Deployment and ClusterIP
Service → localhost port-forward. It does not manage EC2 or incur EKS charges.
Both paths use the same FastAPI image and expose health and version information.

```mermaid
sequenceDiagram
  participant User as Developer
  participant Git as GitHub Actions
  participant Reg as GHCR
  participant STS as AWS STS/OIDC
  participant SSM as Systems Manager
  participant Host as EC2 Docker
  participant CW as CloudWatch
  User->>Git: Push main
  Git->>Git: Test application and Bash recovery
  Git->>Reg: Publish commit-tagged image
  Git->>STS: Exchange exact repository/main OIDC token
  STS-->>Git: Temporary deployment credentials
  Git->>SSM: Reviewed script and exact image digest
  SSM->>Host: Execute privileged deployment script
  Host->>Reg: Pull public image anonymously
  Host->>Host: Preserve verified release; start candidate
  Host->>Host: Check /health and expected /version
  Host->>CW: Application stdout/stderr via awslogs
  Host-->>SSM: Success, or failed candidate with recovery result
  SSM-->>Git: Execution status and exit code
```

## Identities

- Local bootstrap access provisions Terraform resources in the explicit workload
  account allowlist. It is separate from GitHub's deployment identity.
- The EC2 instance profile grants SSM managed-node access and creation/writes only
  to streams in the application log group. Docker's host-side awslogs driver uses
  that role through instance metadata; keys are not copied into the container.
- GitHub's OIDC trust requires the issuer, STS audience, immutable repository
  identity and main ref. Only the deployment job can request an identity token.
- The deployment policy permits SendCommand for the specific EC2 and AWS shell
  document, plus regional GetCommandInvocation (an action without resource scoping).
- GitHub's generated token publishes the package. Public EC2 pulls need no PAT.

## Network and data paths

Inbound HTTP 80 accepts only the configured client IPv4 /32. There is no SSH rule.
Outbound HTTPS permits package/registry downloads, SSM and logs endpoints through
the internet gateway. Public IPv4 is automatically allocated while running; no
Elastic IP or NAT is needed. A stopped/restarted instance can obtain a new address.
An ISP address change can require an explicitly reviewed client allowlist update.

The deployment runner never needs inbound HTTP access. SSM executes checks on the
host's loopback port 80; client-side HTTP is a separate reachability verification.
This is temporary restricted HTTP, not public TLS or a service for sensitive data.

Application logs go to the pre-existing regional group with seven-day retention.
CPU and status alarms monitor EC2 metrics, not continuous application health.
Deployment probes are checks during release; no scheduled health monitor is added.

## Release and recovery invariants

The digest selects image content; the full commit SHA identifies the source and
is checked against the image revision label and `/version`. Before mutation, the
script validates inputs, acquires a host lock, validates persisted state, adopts
an actually healthy running release, and pulls/checks the candidate.

One root-only `releases.json` stores current and previous image/version/logging
records. A temporary file in the same directory is renamed atomically. Candidate
failure restores the last verified image with its previous logging options and
normal healthy environment. Recovery is itself health/version checked; it still
returns a failed deployment status. First deploy has no invented rollback target.
A failed recovery reports that operator intervention is required.

Workflow concurrency prevents overlapping main releases. The host lock protects
the application independently of the runner. SSM eventual consistency is retried;
a client polling timeout does not establish that remote execution was cancelled.

## Limits

One host means brief replacement downtime and no high availability. State is local
and must be privately backed up. A corrupt release record fails before replacing
the running app. A stopped host is offline in SSM. Kubernetes replicas are on one
local kind node, so they are not evidence of multi-node or cloud fault tolerance.
