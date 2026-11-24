# Phase 6: CloudWatch monitoring

The existing Terraform log group, scoped instance-role permissions and two EC2
alarms were verified in Phase 3. The deployment now selects Docker awslogs from
the root-owned `/etc/cloudship.env` on EC2. Actual application-event evidence will
be added after the live release is verified.

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
