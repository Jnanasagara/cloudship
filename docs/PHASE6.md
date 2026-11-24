# Phase 6: CloudWatch monitoring

Verified on November 24, 2026. The deployment selects Docker awslogs from the
root-owned `/etc/cloudship.env` on EC2, using the existing Terraform group and
instance IAM role. Actual events were read through CloudWatch APIs.

## Observed results

- [Corrected live release](https://github.com/Jnanasagara/cloudship/actions/runs/45421377573)
  deployed commit `2b1153df72669fa2461a31e109f9c96b421b8805` successfully.
- SSM inspection confirmed the actual container and saved current digest agree,
  the container is running, and its logging driver is `awslogs`.
- CloudWatch contained one actual stream with eight initial events, including
  application startup and successful health/version requests. Further probes
  naturally add events; no synthetic event count is claimed as fixed.
- The application log group retention was seven days.
- Actual EC2 CPU datapoints were returned (12 in the sampled two-hour window).
- Both instance-dimension alarms reported OK with the configured CPU/status
  metric, statistic, threshold and period. No CPU load was generated for evidence.
- The first new-logger trial hit an option rejected by the actual AL2023 host's
  Docker build. It recovered the old healthy image and reported failed deployment.
  Removing the optional explicit stream-creation setting fixed compatibility;
  stream creation uses the driver's default. An executable regression captures
  the actual host behavior rather than assuming every Docker build is identical.

The final pre-teardown check observed three streams and 73 events across the live
baseline, unhealthy candidate and healthy update. These are checkpoint observations,
not invented log entries. Sanitized evidence was saved before approved teardown.

## Configuration

- Group: `/cloudship/dev/app`; retention: seven days.
- Region: Sydney (`ap-southeast-2`), read from the existing host settings.
- Stream: one per release/deployment attempt, including the commit version.
- No group creation from the container driver; Terraform owns that group.
- Docker's host process uses the EC2 role, not keys in application environment.
- The previous release's driver/options are persisted so recovery can restore
  the working configuration even if a candidate's logger fails.
- Local tests/runs use bounded json-file logging without contacting AWS.

```powershell
aws logs describe-log-groups --profile cloudship --region ap-southeast-2 --log-group-name-prefix /cloudship/dev/app
aws logs describe-log-streams --profile cloudship --region ap-southeast-2 --log-group-name /cloudship/dev/app --order-by LastEventTime --descending --limit 5
aws logs filter-log-events --profile cloudship --region ap-southeast-2 --log-group-name /cloudship/dev/app --limit 20
aws cloudwatch describe-alarms --profile cloudship --region ap-southeast-2 --alarm-name-prefix cloudship-dev
```

Raw logs can contain client IPs and other operational metadata; keep them private.
In the console use CloudWatch → Logs → Log groups, then the application group and
latest stream. For metrics use EC2/Per-instance metrics and the Terraform instance
dimension. The CPU alarm uses average CPU over two five-minute periods; the status
alarm uses failed status checks over two one-minute periods. No heavy CPU load is
needed just to show an alarm transition.

Metrics are numerical time series, logs are events, and alarms evaluate metric
thresholds. Neither low CPU nor an OK instance alarm proves application health.
The release script checks application health during deployment; scheduled custom
health metrics and SNS notifications are intentionally outside this small scope.

## Interview checkpoint

- Why retention? It bounds stored log history and helps control costs.
- Who writes logs? Docker's awslogs driver on EC2, authorized by its instance role.
- Why can an EC2 alarm be OK while the API is unhealthy? Instance metrics and HTTP
  behavior measure different layers; use health probes and application logs too.
