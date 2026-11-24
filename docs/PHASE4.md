# Phase 4: GitHub Actions CI/CD

Verified on November 24, 2026. The application is deployed on the existing Sydney
EC2 host; automatic rollback and CloudWatch application log delivery remain pending.

## Delivery flow

1. A push to main starts the application tests on a GitHub-hosted Ubuntu runner.
2. Passing tests allow a separate job to build a Linux AMD64 image and publish it
   to `ghcr.io/jnanasagara/cloudship`, tagged with the full Git commit SHA.
3. The deployment job exchanges GitHub's OIDC identity for temporary AWS credentials.
4. `scripts/deploy_ssm.py` sends the checked-in Bash script through AWS Run Command
   to the Terraform-managed EC2 instance, then polls the execution result.
5. `scripts/deploy.sh` pulls the exact published digest, checks its revision label,
   replaces the application container, and verifies local health and commit version.

Tests and image building run on GitHub's runner. The application runs on EC2.
Health checks execute on EC2 through SSM, so GitHub runners need no inbound HTTP
access. The authorized client can separately verify the public HTTP endpoint.

## Files and configuration

| File | Purpose |
| --- | --- |
| `.github/workflows/deploy.yml` | Test, build/publish, OIDC and deployment jobs |
| `scripts/deploy_ssm.py` | Validate inputs, transport the script and require SSM success |
| `scripts/deploy.sh` | Pull, replace, and verify the application container |
| `requirements-dev.in` | Development dependency inputs tied to the runtime lock |
| `requirements-dev.txt` | Generated versions and hashes for a fresh test installation |

Repository Actions variables:

| Variable | Source |
| --- | --- |
| `AWS_REGION` | `ap-southeast-2` |
| `AWS_ROLE_ARN` | Terraform output `github_deploy_role_arn` |
| `EC2_INSTANCE_ID` | Terraform output `instance_id` |

GitHub supplies `GITHUB_TOKEN` for publication. EC2 pulls the public package without
a GitHub credential. The Docker build allowlist excludes local configuration,
Terraform inputs/state, credentials and private keys. The image is intentionally
public; package visibility is separate from repository visibility.

Only the build job receives `packages: write`; only the deploy job receives
`id-token: write`. The AWS role trusts the exact repository's immutable identity
and main branch, and can send the shell-command document only to the CloudShip host.
No GitHub job environment is configured because adding one changes the OIDC subject.
Actions are pinned to release commit hashes. Workflow concurrency and a host lock
prevent overlapping deployments. Inputs are validated; no shell `eval` is used.

## Verified evidence

| Check | Result |
| --- | --- |
| Fresh CI dependency installation | Hashed runtime and development requirements installed successfully |
| Application tests | Eight tests passed in the normal workflow |
| GHCR publication | Public package published with full commit tags; anonymous manifest access verified |
| Image runtime | Published image served healthy status and exact version in a temporary local container |
| OIDC | Actual GitHub workflow assumed the restricted AWS deployment role |
| SSM deployment | Command completed successfully and the host reported the expected release |
| External HTTP | Root, health and version endpoints verified from the authorized client |
| Failure gate | One intentional failed test, eight passing tests, both downstream jobs skipped |
| Existing release after failed CI | Healthy; version unchanged from the preceding successful push |

Workflow records:

- [First complete deployment](https://github.com/Jnanasagara/cloudship/actions/runs/45409223571)
  deployed commit `585668c73c6b9d1ac8c28396588b49b52d128bce`.
- [Successful update](https://github.com/Jnanasagara/cloudship/actions/runs/45411153351)
  deployed commit `6061fc0e68edb5241ae948061ba67b0735e42b0c`.
- [Intentional CI failure](https://github.com/Jnanasagara/cloudship/actions/runs/45411167308)
  reported `1 failed, 8 passed`; publishing and deployment were skipped.

GitHub logs/artifacts may expire. These links and results record the observed
checkpoint; raw credentials, account IDs, instance IDs and client IPs are not copied
into this guide. Future successful pushes advance the running version.

## Repeat the demonstrations

An ordinary push to main tests, publishes and deploys. The existing host must be
running, fully bootstrapped and online in SSM; the workflow does not start EC2.
Restarting a stopped host requires cost approval and typically changes its public IP.

To demonstrate the failure gate without changing application code:

```powershell
# Explicitly request a temporary failing unit test on the GitHub runner.
gh workflow run deploy.yml --repo Jnanasagara/cloudship --ref main -f fail_ci_demo=true
```

Expect Application tests to fail and both later jobs to be skipped. The synthetic
test is created only on the disposable runner. Ordinary pushes and manual runs
with the default false input do not inject it.

Check the live application using the current Terraform output:

```powershell
# Use the current server IP; keep personal network settings out of Git.
$appIp = terraform -chdir=terraform output -raw public_ip
curl.exe --max-time 15 "http://$appIp/health"
curl.exe --max-time 15 "http://$appIp/version"
```

The version must equal the latest successfully deployed commit, including after
the intentional CI failure. If SSM succeeds but client HTTP times out, check the
client /32 allowlist, current server public IP and routing. The approved Phase 4
network repair replaced only the existing HTTP source /32; it did not open SSH,
allow unrestricted HTTP, or replace EC2. Local ignored tfvars were aligned afterward.

## Limits and lifecycle

- Single-instance replacement briefly interrupts service; this is not zero downtime.
- A failed deployment is reported to GitHub, but restoring the previous image is
  Phase 5 work. Docker's restart policy is not automatic rollback.
- Container logs currently use bounded local logging. CloudWatch app log delivery
  will be configured and verified in Phase 6.
- A timed-out SSM poll does not prove the remote command stopped. Inspect its
  execution status before retrying.
- EC2 is running at this checkpoint. Compute and public IPv4 total approximately
  $0.0182/hour before credits, plus storage, monitoring and any chargeable traffic.
  Credits cover only eligible usage; budget alerts are not a hard cap.
- Stop idle compute after the cloud demonstrations. Stopping retains chargeable
  storage/alarms. See [Phase 3 cleanup](PHASE3.md) for approved teardown; regenerate
  any cleanup plan after state changes rather than reusing a stale saved plan.

## Interview checkpoint

- What did we build? A tested commit becomes an identifiable container image and
  reaches EC2 through an authenticated, observable delivery pipeline.
- Why OIDC and SSM? GitHub obtains temporary AWS credentials, and SSM executes the
  deployment without inbound SSH or stored SSH keys.
- Why a digest as well as a commit tag? The tag identifies the source revision;
  the digest selects the exact published image content, even if a tag changes.
- What stops a broken test reaching EC2? Job dependencies prevent build/publication
  and deployment after the test job fails; the manual demonstration verified this.
- One failure we diagnosed: CI initially rejected the mixed hashed/unhashed
  dependency requirements. Generating a fully hashed development lock fixed fresh
  installation while keeping runtime versions aligned.
