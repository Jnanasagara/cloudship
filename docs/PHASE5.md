# Phase 5: health checks and automatic rollback

Implementation and isolated Linux tests are complete. Live demonstration evidence
will be recorded after the tested workflow is published and run.

## Behavior

`deploy.sh IMAGE_DIGEST COMMIT_SHA [healthy|unhealthy-demo]` runs as root through
SSM. Default mode is healthy. It validates the public image namespace, digest and
full SHA; acquires the same host lock as Phase 4; and validates recovery state.
The actual healthy running Phase 4 container is adopted on the first upgrade.

`/var/lib/cloudship/releases.json` is root-readable and contains current/previous
image, version and Docker logging configuration. Changes use a same-directory
temporary file and atomic rename. Missing images or mismatched revision labels
fail before stopping the old application. Successful candidates become current;
failed starts/health checks recover the prior image and logging options.

Rollback validates the restored `/health` and `/version`, and returns nonzero so
GitHub still marks the candidate release failed. With no prior verified release,
the failed initial container is removed and the lack of a recovery target is
reported. A failed recovery is also explicit; no false success is returned.

## Controlled live demonstration

Do this only while the project host is running and healthy. Obtain approval before
intentionally disrupting a shared/live service. In this learning project the user
authorized completing all remaining phases and their planned demonstrations.

1. Push the tested recovery implementation normally and verify healthy release A.
2. Set `PAUSE_AUTO_DEPLOY=true` so a new main push tests/publishes without replacing A.
3. Create a distinct candidate commit B (a documented empty demonstration commit is
   sufficient: its revision label and digest differ), then push it and wait for
   publication. Confirm the app still serves A.
4. Manually run main with `simulate_unhealthy=true`. The helper accepts this only
   for workflow_dispatch on main and explicitly authorizes the host failure mode.
5. Observe B return bad health, the workflow fail, recovery report A, and external
   `/version` still equal A. Compare the exact recovered digest in release state.
6. Reset `PAUSE_AUTO_DEPLOY=false` and run main normally to verify healthy A → B.

```powershell
gh variable set PAUSE_AUTO_DEPLOY --repo Jnanasagara/cloudship --body true
git commit --allow-empty -m "Prepare distinct rollback demonstration candidate"
git push origin main
# Wait for tests/publication, with deployment skipped, before continuing.
gh workflow run deploy.yml --repo Jnanasagara/cloudship --ref main -f simulate_unhealthy=true
# Inspect actual recovery and health/version before restoring normal deployment.
gh variable set PAUSE_AUTO_DEPLOY --repo Jnanasagara/cloudship --body false
gh workflow run deploy.yml --repo Jnanasagara/cloudship --ref main
```

## Local checks

The Linux suite executes the actual Bash script/jq against external-tool fixtures.
It covers successful state promotion, actual previous-image recovery, unhealthy
first deployment, failed start, missing image, failed rollback, corrupt/stale
state, invalid input, explicit failure authorization and logging restoration.
The transport tests check manual/main restrictions, propagation retry and rejection
of unsuccessful SSM results. Actual Docker/AWS results remain separate live evidence.

## Interview checkpoint

- Why is restart not rollback? Restart reruns the same image; rollback recreates
  the previous verified image and validates its old version.
- Why must GitHub stay red after successful recovery? The requested release failed;
  recovery preserves availability but does not make that release acceptable.
- What if the first release fails? There is no known-good image to claim restored;
  report failure clearly and retain diagnostics.
