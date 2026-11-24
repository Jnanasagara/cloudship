# Phase 7: local kind Kubernetes

This exercise is local Kubernetes inside Docker Desktop, not EKS and not the EC2
deployment. The project-local kind binary is checksum verified; the node image is
pinned to Kubernetes 1.34.11 to match kubectl 1.34.1. An ignored dedicated kubeconfig
avoids changing another cluster's context. The complete local exercise was verified
on November 24, 2026, and the project-created cluster was removed afterward.

## Observed results

- Server-side manifest validation passed; Deployment rolled out with two Ready Pods.
- Localhost-only port-forward returned healthy status and version
  `6061fc0e68edb5241ae948061ba67b0735e42b0c` from the pinned image.
- Actual Pod logs contained successful health/version HTTP requests.
- Scaling reached three Ready replicas, then returned to two.
- One project Pod was deleted; a replacement with a new UID became Ready and the
  Deployment recovered two replicas.
- An atomic image+APP_VERSION patch rolled to the distinct published release
  `585668c73c6b9d1ac8c28396588b49b52d128bce`; rollout and localhost health/version
  verification passed. Port-forward was restarted after its selected Pod changed.
- No PVCs or PVs existed. The task-created ownership marker was checked, the
  port-forward stopped, and `kind delete cluster` used the same private kubeconfig.
  `kind get clusters` then reported no clusters. No AWS/EKS resource was created.

Private command output and kubeconfig remain in ignored local artifacts, not Git.
The tracked manifest retains the initial verified digest/version for reproduction.

## Workload

The Deployment has two replicas, a digest-pinned public image and matching version,
50m/64Mi requests, 250m/128Mi limits, startup/readiness/liveness probes, non-root
UID/GID 10001, read-only root filesystem, dropped capabilities and no mounted
service-account token. The Service is ClusterIP; it creates no cloud load balancer.

Follow README's cluster/apply/port-forward commands, then inspect:

```powershell
$kc = Join-Path $PWD.Path '.artifacts\kind.kubeconfig'
kubectl --kubeconfig $kc --context kind-cloudship get pods,deployments,services
kubectl --kubeconfig $kc --context kind-cloudship logs deployment/cloudship --tail=20
kubectl --kubeconfig $kc --context kind-cloudship describe deployment cloudship
kubectl --kubeconfig $kc --context kind-cloudship scale deployment/cloudship --replicas=3
kubectl --kubeconfig $kc --context kind-cloudship rollout status deployment/cloudship
kubectl --kubeconfig $kc --context kind-cloudship scale deployment/cloudship --replicas=2
```

For rolling update, patch the container image **and** APP_VERSION in the same Pod
template update to another verified published release. Wait for rollout and check
the new version through the service. Delete one project Pod and confirm a new Pod
UID becomes Ready while the Deployment returns to two replicas. Keep kubectl
explicitly scoped to this kubeconfig/context for every operation.

Stop port-forward when finished and remove only the project-created cluster:

```powershell
.\.tools\kind.exe delete cluster --name cloudship --kubeconfig $kc
```

## Interview checkpoint

- Pod vs Deployment vs Service? A Pod runs containers, a Deployment reconciles
  replicas/updates, and a Service gives stable routing to selected ready Pods.
- Why probes? Startup allows boot time, readiness controls traffic eligibility,
  and liveness detects a stuck process; they are not a substitute for rollback.
- Why not LoadBalancer? This is local kind; localhost port-forward demonstrates
  access without provisioning a paid AWS load balancer.
