#!/usr/bin/env bash
# Deploy one reviewed CloudShip release on the EC2 host.
set -Eeuo pipefail

trap 'echo "Deployment failed on line $LINENO" >&2' ERR

if [[ "$EUID" -ne 0 || "$#" -ne 2 ]]; then
  echo "Usage: sudo bash deploy.sh IMAGE_DIGEST COMMIT_SHA" >&2
  exit 1
fi

image_ref="$1"
version="$2"

# Accept only our registry image, pinned to an exact digest.
if [[ ! "$image_ref" =~ ^ghcr\.io/jnanasagara/cloudship@sha256:[a-f0-9]{64}$ ]]; then
  echo "Invalid CloudShip image reference." >&2
  exit 1
fi

if [[ ! "$version" =~ ^[a-f0-9]{40}$ ]]; then
  echo "Version must be a full Git commit SHA." >&2
  exit 1
fi

# Prevent overlapping deployments on this host.
exec 9>/var/lock/cloudship-deploy.lock
flock -w 30 9

docker info >/dev/null
command -v curl >/dev/null
command -v jq >/dev/null

# Download and validate the candidate before changing the running application.
docker pull "$image_ref"
revision="$(docker image inspect \
  --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' \
  "$image_ref")"

if [[ "$revision" != "$version" ]]; then
  echo "Image revision does not match the requested commit." >&2
  exit 1
fi

# A single-container replacement briefly interrupts the application.
if docker container inspect cloudship >/dev/null 2>&1; then
  docker stop --time 10 cloudship
  docker rm cloudship
fi

docker run --detach \
  --name cloudship \
  --restart unless-stopped \
  --publish 80:8000 \
  --env "APP_VERSION=$version" \
  --env ALLOW_FAILURE_DEMO=false \
  --env SIMULATE_UNHEALTHY=false \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  "$image_ref"

# Check from EC2 itself; GitHub runners do not need inbound HTTP access.
for attempt in {1..30}; do
  if curl -fsS --max-time 3 http://127.0.0.1/health \
      | jq -e '.status == "healthy"' >/dev/null \
    && curl -fsS --max-time 3 http://127.0.0.1/version \
      | jq -e --arg version "$version" \
          '.service == "cloudship" and .version == $version' >/dev/null; then
    echo "Deployment succeeded: $version"
    exit 0
  fi

  echo "Waiting for application readiness ($attempt/30)..."
  sleep 2
done

echo "Application failed health/version verification." >&2
docker logs --tail 50 cloudship >&2 || true
exit 1