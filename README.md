# CloudShip

A DevOps project demonstrating Terraform infrastructure,
GitHub Actions delivery, monitoring, rollback and local Kubernetes.

## Planned architecture

GitHub Actions → GHCR → AWS Systems Manager → EC2 running Docker.

Terraform will define the AWS infrastructure.
CloudWatch will collect application logs and monitor instance metrics.
kind will run the same application locally in Kubernetes.

## Progress

- [x] Phase 0: Prerequisites and repository setup
- [x] Phase 1: FastAPI application and tests
- [ ] Phase 2: Docker containerization
- [ ] Phase 3: Terraform AWS infrastructure
- [ ] Phase 4: GitHub Actions CI/CD
- [ ] Phase 5: Health checks and automatic rollback
- [ ] Phase 6: CloudWatch verification
- [ ] Phase 7: Local Kubernetes with kind
- [ ] Phase 8: Runbooks, evidence and interview preparation

## Setup decisions

- Target repository: Jnanasagara/cloudship (private during development)
- Planned AWS region: ap-south-1 (Mumbai)
- Terraform, AWS CLI and kind: setup pending

## Safety

No CloudShip AWS resources have been provisioned.
Cloud provisioning and destructive operations require explicit approval.
Credentials, private keys and Terraform state must stay out of Git.

## Local development

Requires Python 3.11 or newer.

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m pytest -q

$env:APP_VERSION = "local-dev"
$env:ALLOW_FAILURE_DEMO = "false"
$env:SIMULATE_UNHEALTHY = "false"

.\.venv\Scripts\python.exe -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8000
```

Stop the server with Ctrl+C.

### Endpoints

- `GET /`: service name and running message.
- `GET /health`: HTTP 200 when healthy.
- `GET /version`: release identifier from APP_VERSION; defaults to local-dev.

### Controlled unhealthy demonstration

Before starting the server, explicitly set both ALLOW_FAILURE_DEMO
and SIMULATE_UNHEALTHY to "true" to enable the demonstration.

In this mode, /health returns HTTP 503 and /version remains available.
Simulation without permission is rejected during startup.

Restart the application after changing these settings.
Restore both flags to "false" afterward.

Normal deployments must explicitly disable both flags.
Automatic deployment and rollback are not implemented yet.