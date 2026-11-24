# CloudShip operational runbook

Use the workload account in Sydney, not the organization management account/root.
Keep state, personal variables, raw logs and kubeconfig private. Pause automatic
push deployment before investigating an unstable release:

```powershell
gh variable set PAUSE_AUTO_DEPLOY --repo Jnanasagara/cloudship --body true
```

This pauses push deployment only; manual main runs remain available. Reset it to
false after the incident/demo. Never broaden SSH/HTTP ingress to troubleshoot SSM.

## Initial triage

1. Record the failing run, commit, expected image digest, SSM command ID and time.
2. Check the failed job/step before retrying. A failed test should skip publication
   and deployment; an intentionally failed rollback demo should leave the service
   at the old healthy version while GitHub correctly remains red.
3. Verify local identity and current application outputs:

```powershell
aws sts get-caller-identity --profile cloudship --region ap-southeast-2
$instance = terraform -chdir=terraform output -raw instance_id
$appIp = terraform -chdir=terraform output -raw public_ip
aws ec2 describe-instance-status --profile cloudship --region ap-southeast-2 --instance-ids $instance --include-all-instances
aws ssm describe-instance-information --profile cloudship --region ap-southeast-2 --filters "Key=InstanceIds,Values=$instance"
curl.exe --max-time 15 "http://$appIp/health"
curl.exe --max-time 15 "http://$appIp/version"
```

## Failed application/CI tests

Open the first failed step. A dependency installation failure is different from a
test failure. Mixed hashed/unhashed requirements fail on fresh installations;
regenerate `requirements-dev.txt` from its `.in`, preserving runtime constraints.
Run the Python suite and Linux test container before pushing. The manual
`fail_ci_demo` deliberately creates one temporary failing test; do not weaken job
dependencies or add continue-on-error to make it green.

## Failed GHCR publication or pull

Check the image namespace is lowercase and owned by the workflow's repository
owner. Only the build job needs `packages: write`; publication uses the generated
GitHub token. A pre-existing package may need explicit repository Actions access.
Package visibility is independent of repository visibility. EC2's credential-free
pull requires the image package to be public. Check the exact commit tag/digest,
network/DNS and egress HTTPS; do not introduce a broad personal GitHub token into
SSM parameters or image layers.

## OIDC role denied

Check that the job runs from main, has `id-token: write`, uses the intended role
ARN/region, and requests the STS audience. Compare the repository's actual subject:

```powershell
gh api repos/Jnanasagara/cloudship/actions/oidc/customization/sub
```

New repositories can use immutable owner/repository IDs. Adding a job environment
also changes the subject. Align exact trust instead of widening it to `repo:*`.
The local bootstrap profile and GitHub deploy role are separate identities. A
service-control-policy explicit deny cannot be bypassed by attaching more IAM
Allow policies; resolve the actual account/organization restriction.

## Local AWS login expired or wrong account

Run `aws login --profile cloudship --region ap-southeast-2` (the profile argument
matters). Select the workload project/assumed role, then confirm STS identity.
Browser sessions are separate across Brave, Codex's browser and private windows.
If the login page shows only management root, open the workload console in the
same browser as the new authorization URL. Do not approve overwriting the profile
with root/management credentials. Never share authorization URLs or tokens.

## SSM offline or command timed out

Check EC2 is running, both status checks pass, bootstrap finished, agent is active,
the instance profile is attached, and HTTPS egress/DNS/routes are correct. A stopped
instance cannot receive commands. A timeout in the GitHub poll does **not** mean
the remote command was cancelled. Inspect the recorded command before retrying:

```powershell
# Use the command ID printed by the failed workflow.
aws ssm get-command-invocation --profile cloudship --region ap-southeast-2 --command-id COMMAND_ID --instance-id $instance
```

For read-only host inspection, use Systems Manager Run Command → AWS-RunShellScript
on this instance, or submit these commands through the CLI. No SSH key is required:

```bash
systemctl is-active docker amazon-ssm-agent
cloud-init status
docker ps -a
docker logs --tail 50 cloudship
docker inspect cloudship
cat /var/lib/cloudship/releases.json
curl -fsS http://127.0.0.1/health
curl -fsS http://127.0.0.1/version
```

Do not publish unredacted inspect output or application logs. Bootstrap output is
in `/var/log/cloudship-bootstrap.log` and cloud-init's output log.
Failed-candidate diagnostics are stored privately as root-readable
`/var/lib/cloudship/failed-*.log` files (at most 16 KiB per attempt); Actions emits
only structured release outcomes. Inspect raw diagnostics through authorized SSM
or CloudWatch, not public GitHub log output.

## Unhealthy candidate or failed rollback

Read the candidate diagnostic logs, rollback decision and restored version. Verify
the running container's Config.Image digest and APP_VERSION agree with the saved
current release. Recovery must clear both failure flags and restore the old logging
configuration. A candidate can fail because of pull/revision mismatch, Docker
permissions, port conflicts, crashes, bad health or logging initialization.

If rollback failed, keep push deployment paused. Determine why Docker cannot start
the saved known-good image (port 80 ownership, daemon health, image availability,
logging permissions/configuration). Once fixed, invoke the installed reviewed
script through SSM with the saved current image and version in healthy mode:

```bash
bash /opt/cloudship/bin/deploy.sh 'ghcr.io/jnanasagara/cloudship@sha256:EXACT_SAVED_DIGEST' 'EXACT_SAVED_COMMIT' healthy
```

Replace both placeholders with validated values from the private state; the script
rejects invalid formats. Do not invent a prior image on a first deployment. Do not
edit a damaged state file blindly; preserve it privately and inspect the actual
healthy container. Restore normal deployment only after health/version verification.

## EC2 HTTP unreachable while deployment passed

The SSM checks use EC2 loopback, so success does not prove client reachability.
Check the current server public IP, client /32 ingress, public subnet route to an
active internet gateway, and the container's 80:8000 mapping. A changed client IP
requires a reviewed single-/32 update and matching ignored tfvars. A restarted
host usually gets a different server IP; refresh state/outputs before browsing.
Do not use unrestricted 0.0.0.0/0 or SSH as a shortcut. Compare health/version, not
only a Docker running flag. This project uses HTTP, not HTTPS on port 443.

## Missing CloudWatch application logs

Inspect `HostConfig.LogConfig`: it must be awslogs with the intended region/group
and an actual stream. The host settings file must exist, the Terraform group must
already exist, retention must be seven days, and the EC2 role must allow
CreateLogStream/PutLogEvents on that group's streams. Docker's daemon uses the
instance profile and needs metadata access; application environment must not
contain AWS keys. Check SSM/bootstrap and Docker daemon logs for driver errors.
Allow a short delivery delay and generate a small health/version request.

```powershell
aws logs describe-log-streams --profile cloudship --region ap-southeast-2 --log-group-name /cloudship/dev/app --order-by LastEventTime --descending --limit 5
aws logs filter-log-events --profile cloudship --region ap-southeast-2 --log-group-name /cloudship/dev/app --limit 20
```

## Alarm investigation

Inspect the alarm metric, instance dimension, statistic, period, threshold and
missing-data setting. CPU average is not an HTTP health metric. Check app logs,
host health, container state and version together. Stopped hosts can lack metric
data and be offline in SSM. No alarm actions/SNS are configured; the alarms are
visible monitoring records. Do not generate sustained CPU stress merely for proof.

## Terraform errors and drift

- Run fmt/validate and inspect exact error lines; Terraform resource names must
  match references and IAM JSON uses jsonencode, not jsondecode on an object.
- Refresh the named AWS profile if credentials expire; confirm workload account.
- Preserve the ignored state/backups; never commit them or use force-unlock
  without proving the lock's owner is gone.
- Review replacements caused by newer public AMI parameters or user-data changes.
- A saved plan is tied to state and input values. Regenerate it after changes.
- A targeted plan is an exceptional narrow repair, not routine drift verification.
  The approved Phase 4 /32 repair used targeting to avoid unrelated AMI replacement.

## Local Kubernetes failures

Always pass the dedicated kubeconfig and `kind-cloudship` context. Inspect pods,
events, rollout status and logs. ImagePullBackOff can mean a private/missing image,
bad digest or local networking. CrashLoopBackOff requires container logs; unready
Pods require probe/port/health checks. ReadOnlyRootFilesystem and non-root settings
are intentional; the app must not depend on writing to its image filesystem.
Use the matched Kubernetes node version and sufficient Docker Desktop resources.
Port-forward binds localhost and ends when its process stops. It is not a cloud
LoadBalancer. Do not delete another existing cluster to fix this project.

## Cost pause and cleanup

Pause automatic push deployment before stopping/deleting the host. With approval,
stop the Terraform-owned instance; expect SSM offline and automatic public-IP
release, while EBS/alarms remain. Before final teardown, save sanitized evidence,
back up private state, regenerate and inspect the exact destroy plan, and obtain
approval for deleting the project-owned resources. Apply only that reviewed plan.
Verify removal through AWS APIs and an empty managed-resource state. Never delete
pre-existing untagged instances/disks or unrelated organization accounts.

Delete the local kind cluster only when this task created it, and stop its
port-forward process. Local tool/image cache files incur no AWS bill. GHCR packages
are not Terraform-managed; decide separately whether to retain public demo images.
