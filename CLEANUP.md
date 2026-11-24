# Verified project cleanup

Completed November 24, 2026, after the live delivery, failed-release recovery,
CloudWatch and local Kubernetes demonstrations were verified.

## AWS

The user approved the concrete Terraform preview: **0 added, 0 changed, 20
destroyed**, including the project EC2/root disk, log group/events, alarms, project
IAM/OIDC and networking. Before execution, the workload identity, exact plan hash,
resource ID inventory and absence of unrelated OIDC role consumers were checked.
Private state/evidence were preserved outside Git.

Actual apply result:

```text
Apply complete! Resources: 0 added, 0 changed, 20 destroyed.
```

Read-only AWS absence checks confirmed:

- The project instance is terminated/absent and its root volume is absent.
- The dedicated VPC is absent; Terraform completed its dependent route, subnet,
  internet gateway and security-group deletions.
- Both project metric alarms and the application log group are absent.
- Both project roles, their instance profile and the GitHub OIDC provider are absent.
- Terraform state has **zero managed resources** remaining.

Sydney inventory afterward showed **zero running EC2 instances**. One unrelated
pre-existing stopped instance and one 8 GiB disk remain; they were not modified or
deleted. Retained EBS can still incur storage charges. Other regions/account-wide
billing were not re-audited, so this is not a guarantee of a zero AWS invoice.
The paid plan, organization, billing setup and budget were not deleted or changed.

## Local Kubernetes

Only the cluster created by this task was removed after all demonstrations. Its
creation marker and zero persistent volumes/claims were checked first. Cleanup
used the same dedicated private kubeconfig as creation. The port-forward stopped;
`kind get clusters` reported no clusters. No unrelated Kubernetes context was changed.

Local cached Docker images/test tools remain for reproduction and incur no AWS
resource usage. Public GHCR images and Git source were intentionally retained.

## Reproduction after cleanup

The cloud application is intentionally offline. GitHub repository variable
`PAUSE_AUTO_DEPLOY=true` pauses push deployment while tests/publication remain
available. Manual deployment also requires newly provisioned, ready infrastructure;
do not manually dispatch it against deleted instance/role identifiers.

To redeploy: review current costs and the new Terraform plan, obtain provisioning
approval, apply it, update AWS_ROLE_ARN/EC2_INSTANCE_ID from new outputs, verify EC2
checks and SSM, then reset PAUSE_AUTO_DEPLOY to false. Recheck the client /32 and new
public IP. Do not reuse stale saved plans or restore deleted resource IDs into state.
Local kind can be recreated independently from the README without any AWS services.
