# CloudShip

A DevOps project demonstrating Terraform infrastructure,
GitHub Actions delivery, monitoring, rollback and local Kubernetes.

## Planned architecture

GitHub Actions → GHCR → AWS Systems Manager → EC2 running Docker.

Terraform will define the AWS infrastructure.
CloudWatch will collect application logs and monitor instance metrics.
kind will run the same application locally in Kubernetes.

## Progress

- [ ] Phase 0: Prerequisites and repository setup
- [ ] Phase 1: FastAPI application and tests
- [ ] Phase 2: Docker containerization
- [ ] Phase 3: Terraform AWS infrastructure
- [ ] Phase 4: GitHub Actions CI/CD
- [ ] Phase 5: Health checks and automatic rollback
- [ ] Phase 6: CloudWatch verification
- [ ] Phase 7: Local Kubernetes with kind
- [ ] Phase 8: Runbooks, evidence and interview preparation

## Setup decisions

- Target repository: Jnanasagara/cloudship (public)
- Planned AWS region: ap-south-1 (Mumbai)
- Terraform, AWS CLI and kind: setup pending

## Safety

No CloudShip AWS resources have been provisioned.
Cloud provisioning and destructive operations require explicit approval.
Credentials, private keys and Terraform state must stay out of Git.