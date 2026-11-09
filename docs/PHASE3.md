# Phase 3: Terraform infrastructure

## Status

The application and container were verified in Phases 1 and 2. Phase 3 defines the
AWS host and its supporting infrastructure; it does not deploy the application.

- [x] Networking, security groups, EC2, instance IAM and common tags implemented.
- [x] CloudWatch log group and two EC2 metric alarms implemented.
- [x] GitHub OIDC provider, exact repository/main trust and SSM permissions implemented.
- [x] Region and workload-account restrictions implemented.
- [x] Terraform formatting and validation passed; plan proposes 20 additions.
- [x] All eight application tests and the installed-dependency compatibility check passed.
- [x] Wrong-account credentials are rejected; the rendered bootstrap passed Bash syntax checking.
- [x] The selected AWS AMI is available, x86-64 and compatible with the 8 GiB root disk.
- [x] User approved the reviewed plan after credit review and chose to proceed without a separate Billing Support consultation.
- [x] Approved plan applied: 20 added, 0 changed, 0 destroyed.
- [x] Live AWS security, storage, IAM, network, tags and monitoring checks passed.
- [x] Docker installation, completed bootstrap and Systems Manager connectivity verified on the host.
- [x] EC2 system/instance status checks passed and both metric alarms reported OK.
- [x] Post-apply Terraform plan reported no changes.

The master brief's Phase 3 acceptance checks passed on November 9, 2026. See
[the verification record](PHASE3_VERIFICATION.md). This does not complete the full
resume claims: deployment, rollback, application log delivery, Kubernetes and
actual teardown verification remain pending.

## Resource inventory

| Group | Count | Purpose |
| --- | ---: | --- |
| VPC, subnet, internet gateway, route table, route, association | 6 | Dedicated public-subnet network |
| Security group and separate ingress/egress rules | 3 | Client `/32` HTTP ingress and HTTPS egress |
| EC2 instance | 1 | Amazon Linux 2023, x86-64, `t3.micro` |
| EC2 role, profile, SSM attachment, log-publishing inline policy | 4 | Host credentials without stored access keys |
| CloudWatch log group and two metric alarms | 3 | Seven-day log retention, CPU and EC2 status checks |
| GitHub OIDC provider, role and inline policy | 3 | Temporary deployment credentials and scoped SSM commands |
| **Total** | **20** | **One small demonstration environment** |

The instance has an 8 GiB encrypted gp3 root volume, deleted with the instance.
IMDSv2 tokens are required. T3 CPU credits use Standard mode to avoid Unlimited
surplus-credit charges. There is no SSH ingress, SSH key, NAT gateway, load
balancer, database or managed Kubernetes cluster.

HTTP ingress is only from the explicitly configured client IPv4 `/32`. The route
`0.0.0.0/0` provides internet routing; the security group separately controls
permitted traffic. Replies to allowed connections are statefully permitted.

## Local inputs and authentication

Use the `cloudship` CLI profile for the original **Hold My Coffee** workload
account, not the organization management or Identity Delegated Admin accounts.
Store the real workload account ID and client IP only in ignored
`terraform/terraform.tfvars`. `terraform.tfvars.example` contains example values
and is not automatically loaded. `allowed_account_ids` protects against selecting
the wrong account even if the profile changes.

```powershell
# Refresh temporary browser-based credentials when the session expires.
aws login --profile cloudship --region ap-southeast-2

# Inspect the selected account before any cloud operation.
aws sts get-caller-identity --profile cloudship --region ap-southeast-2 --no-cli-pager

# Install the locked provider on a fresh checkout without changing its selection.
terraform -chdir=terraform init -lockfile=readonly

# Format, validate and generate a saved plan without creating resources.
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan -input=false "-out=phase3.tfplan"
```

Review all actions, especially the account, region, instance size, root volume,
network rules and IAM trust. Expected: **20 to add, 0 to change, 0 to destroy** for
the first deployment. The saved plan contains local values and must stay ignored,
along with state, logs, `.terraform/` and real variables. Do not publish raw plans
or plan JSON as evidence. Commit `.terraform.lock.hcl` so provider selections are
repeatable. State is local for this learning project and must be backed up securely.

## Costs and approval boundary

The AWS account was upgraded and advanced features activated manually. After
activation, the management-account Billing console was inspected directly: two
active credits total **$120**, with **$0 used**, expiring **November 8, 2027**.
The Free Tier credit's applicable-service list includes EC2, CloudWatch, VPC and
Systems Manager, and organization credit sharing is activated for the workload
account. The workload account's Free Tier plan-state API returned missing data,
so that API was not used as evidence of a zero balance or credit expiration.

The user requested use of the existing credits. After the coverage review and
explanation of non-covered charges, the user chose to proceed without a separate
Billing Support consultation. The reviewed plan was applied. Eligible-service
coverage and sharing are confirmed; zero out-of-pocket charges are not guaranteed.
Credit application and tax treatment on a finalized invoice have not been verified.

The $5 monthly budget notifies at configured thresholds; it does not stop spend.
Advanced-feature activation removed project spend limits. Credits expire and
exclude some charges, including applicable taxes. No promise of a zero cash bill
is made. Further provisioning or destructive changes require explicit approval.

Sydney Linux On-Demand `t3.micro` pricing was checked using the AWS Price List API:
**$0.0132 per instance-hour**. gp3 storage is **$0.096 per GB-month**, so 8 GiB is
about **$0.77 per month** while allocated, at baseline IOPS and throughput. A public
IPv4 address is **$0.005 per hour**. The AWS Price List API also returned
**$0.10 per standard alarm metric-month** (about **$0.20/month** for our two alarms)
and **$0.67/GB** for standard custom-log ingestion in Sydney. Log storage, queries
and any chargeable data transfer are additional usage-based items. These estimates
do not subtract any applicable free allowances. Avoid heavy traffic and logging.

For 100 instance-hours, compute plus IPv4 is approximately **$1.82**, plus the
allocated disk, monitoring and transfer. Reserve **$10-$20 in credits** for short
development/demo sessions and cleanup. This is a planning allowance, not a hard
cap, and does not cover indefinite hosting or unexpected usage. Recheck prices
and billing immediately before launch. Stopping EC2 does not delete its EBS disk
or monitoring resources; approved teardown is the final cost-control step.

The existing `cloudship-monthly` budget was read back through the AWS Budgets API
and still has a **$5 USD** monthly limit. This confirms its configuration, not
notification delivery or a hard spending cap.

Sources: [EC2](https://aws.amazon.com/ec2/pricing/on-demand/),
[EBS](https://aws.amazon.com/ebs/pricing/),
[public IPv4](https://aws.amazon.com/vpc/pricing/),
[CloudWatch](https://aws.amazon.com/cloudwatch/pricing/),
[credit terms](https://aws.amazon.com/awscredits/),
[advanced features](https://docs.aws.amazon.com/accounts/latest/reference/activate-advanced-features.html).

**Only after approval of the reviewed saved plan:**

```powershell
# This creates billable AWS infrastructure: run only after explicit approval.
terraform -chdir=terraform apply phase3.tfplan

# Retrieve the resource identifiers after a successful apply.
terraform -chdir=terraform output

# Confirm that the deployed infrastructure matches the configuration.
terraform -chdir=terraform plan -input=false
```

If the saved plan is regenerated or inputs/configuration change, review the new
plan before applying it. If apply partially fails, inspect state and the error;
do not blindly reapply or manually delete resources. Resources created before an
error can still incur charges.

## Cloud verification after approved apply

These checks passed for the initial deployment; repeat them after future changes:

1. EC2 is running in Sydney with the configured type, subnet and instance profile.
2. Its attached security group has only the client `/32` on TCP 80 inbound, no SSH,
   and TCP 443 outbound. The subnet uses the intended internet route.
3. The root volume is encrypted, 8 GiB gp3 and marked for deletion on termination;
   metadata requires IMDSv2. Supported resources have the three common tags.
4. Systems Manager shows the instance online; allow several minutes for bootstrap.
5. A read-only SSM command confirms cloud-init completed and Docker is active.
6. The CloudWatch log group has seven-day retention; both alarms target the new
   instance. New alarms may show `INSUFFICIENT_DATA` until metrics arrive.
7. The OIDC provider audience and role trust match GitHub, the exact immutable
   repository subject and `main`. The deployment policy permits only the intended
   document/instance for `SendCommand`; result reading is restricted to Sydney.
8. A fresh Terraform plan reports no changes, subject to reviewing any newly
   published AMI returned by the public latest-image parameter.

```powershell
# Obtain the deployed instance identifier without hardcoding it.
$instanceId = terraform -chdir=terraform output -raw instance_id

# Check that Systems Manager has registered the host and reports it online.
aws ssm describe-instance-information --profile cloudship --region ap-southeast-2 --filters "Key=InstanceIds,Values=$instanceId" --query "InstanceInformationList[].{Instance:InstanceId,Status:PingStatus,Platform:PlatformName,Agent:AgentVersion}" --no-cli-pager

# Inspect instance status checks; this does not test HTTP application health.
aws ec2 describe-instance-status --instance-ids $instanceId --include-all-instances --profile cloudship --region ap-southeast-2 --no-cli-pager
```

Use SSM Run Command with `AWS-RunShellScript` for the following read-only host
checks. Capture and inspect its exit code, status and output, not just its command
ID. The existing local Terraform identity performs Phase 3 verification; GitHub
role assumption is tested once the Phase 4 workflow exists.

```bash
# Wait for first-boot setup with a bounded timeout, then check installed services.
set -euo pipefail
timeout 600 cloud-init status --wait
systemctl is-active amazon-ssm-agent
systemctl is-active docker
docker --version
docker info >/dev/null
command -v curl
command -v jq

# Verify bootstrap-created directories, settings and completion evidence.
test -d /opt/cloudship/bin
test -d /var/lib/cloudship
test -r /etc/cloudship.env
grep -F 'CloudShip bootstrap complete' /var/log/cloudship-bootstrap.log
```

If SSM stays offline, inspect the instance profile, HTTPS egress, public IP and
subnet route. Use EC2 console system output or the console's cloud-init diagnostics
when SSM is unavailable. When SSM is working, inspect `/var/log/cloud-init-output.log`
and `/var/log/cloudship-bootstrap.log`. Never open SSH as an automatic workaround.

Bootstrap runs on first launch; changing its template intentionally replaces the
instance. It creates host directories and installs Docker, but does not fetch an
unreviewed deployment script. Phase 4 will send the reviewed versioned script
through SSM. No application container or public HTTP response is expected yet.
Application log events, live OIDC deployment and rollback remain later-phase checks.

## Cleanup, only with explicit approval

```powershell
# Preview teardown first; this does not delete anything.
terraform -chdir=terraform plan -destroy -input=false "-out=cleanup.tfplan"

# DESTRUCTIVE: apply only after explicit approval of the teardown plan.
terraform -chdir=terraform apply cleanup.tfplan

# Confirm Terraform manages no remaining resources; also check AWS and billing.
terraform -chdir=terraform state list
```

Verify the instance terminates, the root disk is deleted, its public address is
released, and the Terraform-owned networking, IAM and monitoring resources are
gone. Check for manual/unmanaged resources and delayed billing updates. AWS account
upgrades, organization configuration and the manually created budget are outside
this Terraform state and are not reversed by teardown. The GitHub OIDC provider is
account-wide; before destroying it, ensure no other project has started using it.

## Interview checkpoint

- **What did we build?** One Terraform-provisioned and verified EC2 Docker host
  with its network, host identity, GitHub deployment identity and monitoring
  configuration. The application deployment is the next phase.
- **Why Terraform?** Configuration describes desired infrastructure. The plan
  previews changes; state maps configuration addresses to actual AWS resources.
- **Common failure:** An organization SCP denied OIDC provider operations despite
  a role named `AccountFullAccessRole`. An explicit organization deny overrides
  role-level allows. Listing succeeded after advanced-feature activation.
- **Why no SSH?** SSM uses authenticated AWS API commands over outbound HTTPS,
  avoiding inbound port 22 and unmanaged SSH keys.
- **Trust policy vs permissions policy?** Trust controls who may assume the role;
  permissions control the AWS operations that the assumed role may perform.
- **What is not proved yet?** Bootstrap and host checks passed, but application
  availability, CloudWatch application log delivery, rollback and GitHub OIDC token
  exchange still need their later-phase demonstrations. Teardown is documented
  and must be approved and verified when the AWS demonstration ends.
