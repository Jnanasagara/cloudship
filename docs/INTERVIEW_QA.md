# Interview questions

1. **What does CloudShip demonstrate?** Terraform-provisioned AWS delivery of a
   tested Docker API, short-lived GitHub OIDC credentials, SSM deployment, health
   checks/recovery, CloudWatch, and a separate local Kubernetes exercise.
2. **Why Terraform?** It records desired resources, dependencies and repeatable
   changes. A plan is reviewable; state maps configuration to actual resource IDs.
3. **Why protect state?** It contains infrastructure metadata and can contain
   sensitive values. Losing it can orphan resources or cause duplicate creation.
4. **Why a dedicated VPC/public subnet?** It makes network boundaries explicit.
   The internet-gateway route and public IP provide outbound access without NAT.
5. **What does the security group permit?** HTTP 80 from one explicit client /32,
   outbound HTTPS for required services, and no inbound SSH.
6. **Role vs policy vs instance profile?** A role is an assumable identity; policies
   define permissions; an instance profile attaches an IAM role to EC2.
7. **Why OIDC instead of AWS secrets?** GitHub exchanges a narrowly trusted identity
   token for temporary credentials. There is no long-lived AWS key to store/rotate.
8. **How is trust restricted?** Exact issuer, STS audience, immutable repository
   identity and main ref. Job environments change the subject and must be accounted for.
9. **Why SSM instead of SSH?** The instance agent accepts authorized AWS commands
   through outbound connectivity; no public SSH port or stored SSH key is required.
10. **What blocks an untested release?** Job dependencies: failed tests skip
    publishing and deployment. The controlled CI failure demonstrated this.
11. **Why commit tags and image digests?** The tag names a source revision; a digest
    selects exact content even if a registry tag is changed or rebuilt.
12. **How does health differ from process state?** A running container can return
    HTTP 503 or the wrong version. The release needs healthy HTTP and the expected SHA.
13. **What is real rollback?** Recreate the previous verified image/configuration,
    verify its old version, and keep the rejected candidate's workflow failed.
14. **What if there is no previous release?** Fail honestly, remove the failed
    initial candidate, and report that there is no known-good recovery target.
15. **Why atomic release state?** One renamed JSON record avoids partially updating
    current and previous image/version/logging values across a failure.
16. **Logs vs metrics vs alarms?** Logs are events; metrics are numeric time series;
    alarms evaluate thresholds. EC2 CPU/status alarms do not prove HTTP availability.
17. **What does a Kubernetes Service do?** It routes to selected ready Pods through
    a stable cluster address. The Deployment handles replica reconciliation/rollout.
18. **Readiness vs liveness vs startup probes?** Readiness controls traffic, liveness
    detects a stuck application, and startup gives boot time before ongoing checks.
19. **Is this Kubernetes on AWS or highly available?** No. kind is local Docker,
    separate from single-instance EC2. Two local replicas do not prove multi-node HA.
20. **What are the cost and security tradeoffs?** No NAT/ALB/EKS/database saves cost;
    one host has downtime. /32 HTTP is temporary restricted access, not public TLS.
    Credits/budgets are not a hard spending cap; stop idle compute and verify cleanup.
