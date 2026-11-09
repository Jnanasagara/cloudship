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
- [x] Phase 2: Docker containerization
- [x] Phase 3: Terraform AWS infrastructure provisioned and verified
- [ ] Phase 4: GitHub Actions CI/CD
- [ ] Phase 5: Health checks and automatic rollback
- [ ] Phase 6: CloudWatch verification
- [ ] Phase 7: Local Kubernetes with kind
- [ ] Phase 8: Runbooks, evidence and interview preparation

## Setup decisions

- Target repository: Jnanasagara/cloudship (private during development)
- AWS region: ap-southeast-2 (Sydney)
- Terraform and AWS CLI: installed and verified
- kind: installation pending
- AWS account: Paid Plan with advanced features enabled; resource creation still requires approval

## Safety

CloudShip's Terraform-managed infrastructure is deployed in Sydney. The EC2 host
is running; the application will be deployed in Phase 4.
Further cloud provisioning and destructive operations require explicit approval.
Credentials, private keys and Terraform state must stay out of Git.
The $5 monthly budget is an alert, not a spending cap. Advanced features remove
AWS project spend limits. Existing credits apply only to eligible charges before
their expiration; paid usage is not automatically stopped when credits run out.

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


## Docker development

Requires Docker Desktop running with Linux containers.

```powershell
# Build the image using the locked runtime dependencies.
docker build --pull -t cloudship:local-v1 .

# Start a non-root container, accessible only from this computer.
docker run -d --name cloudship-local -p 127.0.0.1:8000:8000 -e APP_VERSION=local-v1 -e ALLOW_FAILURE_DEMO=false -e SIMULATE_UNHEALTHY=false cloudship:local-v1

# Verify application health and release identification.
curl.exe -i http://127.0.0.1:8000/health
curl.exe -i http://127.0.0.1:8000/version

# Inspect application logs and the container's runtime identity.
docker logs cloudship-local
docker exec cloudship-local id

# Stop and remove this container; retain the image.
docker stop cloudship-local
docker rm cloudship-local
```

### Configuration

- APP_VERSION identifies the running release.
- UVICORN_PORT controls the container's listening port; default: 8000.
- When changing UVICORN_PORT, update the container side of the port mapping.
- Unhealthy mode requires both ALLOW_FAILURE_DEMO=true and SIMULATE_UNHEALTHY=true.
- Environment settings are supplied when creating a container.
  Recreate the container to change them.

### Dependencies

Edit requirements.in to select direct runtime dependencies.
Generate requirements.txt rather than editing its versions and hashes manually.

```powershell
# Install the dependency compiler into the local development environment.
.\.venv\Scripts\python.exe -m pip install pip-tools==7.6.2

# Regenerate the runtime lock, including package hashes.
.\.venv\Scripts\python.exe -m piptools compile --generate-hashes --no-emit-index-url --no-emit-trusted-host requirements.in
```

Review dependency changes and rerun tests and the Docker build afterward.

### Verified container behavior

- Healthy root, health and version endpoints.
- Runtime user and group IDs: 10001.
- Explicit unhealthy mode returns HTTP 503 while version remains available.
- A second container does not affect the healthy container.
- Configurable container port verified using UVICORN_PORT=8080.
- Demonstration containers stopped and removed; local image retained.

Docker reports process state; HTTP checks establish application health.
Automatic rollback is not implemented yet.

## Terraform infrastructure checkpoint

### Implemented and verified

- Dedicated VPC, public subnet, internet gateway and routing.
- HTTP ingress restricted to an explicitly configured client IPv4 /32.
- No inbound SSH rule; management is designed to use Systems Manager.
- EC2 configuration with encrypted storage and required IMDSv2 tokens.
- Instance IAM permissions for Systems Manager and application log publishing.
- CloudWatch log group with seven-day retention and two EC2 metric alarms.
- GitHub OIDC provider and deployment role restricted to the exact repository and main branch.
- SSM deployment permissions restricted to the CloudShip instance and shell-command document.
- Account allowlist rejects credentials for an unintended AWS account.
- Instance ID, public IP, log group and deployment role ARN outputs.
- Shareable variables example; real variables and Terraform state are ignored.
- Initial apply created 20 resources; a fresh post-apply plan reports no changes.
- Bootstrap template uses Linux line endings; the exact rendered script passed Bash syntax checking without execution.

### Cloud verification and remaining boundaries

EC2 is running and both system and instance status checks pass. Systems Manager
reports the host online. A successful SSM command verified completed cloud-init,
active Docker and SSM services, deployment directories and bootstrap settings.
Live API checks confirmed encrypted storage, IMDSv2, restricted network rules,
IAM policy scopes, supported-resource tags, log retention and both alarms.
Both EC2 metric alarms reported OK during verification.

The earlier organization-policy denial on listing OIDC providers was resolved
after advanced-feature activation. The provider listing returned zero existing
GitHub providers, and Terraform then created the provider and deployment role.
GitHub token exchange and actual deployment permissions will be tested in Phase 4.

Phase 3 acceptance checks passed on November 9, 2026. Application deployment,
CloudWatch application log delivery, rollback and local Kubernetes remain pending.
See [the Phase 3 deployment guide](docs/PHASE3.md) for the resource inventory,
cost assumptions, approval boundary, verification, cleanup and interview checkpoint.
The [Phase 3 verification record](docs/PHASE3_VERIFICATION.md) summarizes the actual
AWS checks without publishing local inputs, state, resource IDs or raw logs.
