#!/usr/bin/env bash
# Deploy an exact image and recover the last verified release on failure.
set -Eeuo pipefail
umask 077
trap 'echo "Deployment error on line $LINENO" >&2' ERR

if [[ "$EUID" -ne 0 || "$#" -lt 2 || "$#" -gt 3 ]]; then
  echo "Usage: sudo bash deploy.sh IMAGE_DIGEST COMMIT_SHA [healthy|unhealthy-demo]" >&2
  exit 1
fi
image_ref="$1"
version="$2"
mode="${3:-healthy}"
if [[ ! "$image_ref" =~ ^ghcr\.io/jnanasagara/cloudship@sha256:[a-f0-9]{64}$ || ! "$version" =~ ^[a-f0-9]{40}$ ]]; then
  echo "Invalid CloudShip image digest or commit SHA." >&2
  exit 1
fi
if [[ "$mode" != healthy && "$mode" != unhealthy-demo ]]; then
  echo "Unknown deployment mode." >&2
  exit 1
fi
if [[ "$mode" == unhealthy-demo && "${CLOUDSHIP_ALLOW_FAILURE_DEMO:-false}" != true ]]; then
  echo "Unhealthy demonstration requires explicit authorization." >&2
  exit 1
fi

exec 9>/var/lock/cloudship-deploy.lock
flock -w 30 9
command -v jq >/dev/null
command -v curl >/dev/null
docker info >/dev/null
state_dir="${CLOUDSHIP_STATE_DIR:-/var/lib/cloudship}"
install -d -m 0700 "$state_dir"
state_file="$state_dir/releases.json"
current='null'
previous='null'
baseline_healthy=false

valid_release() {
  jq -e '
    type == "object" and
    (.image | type == "string" and test("^ghcr\\.io/jnanasagara/cloudship@sha256:[a-f0-9]{64}$")) and
    (.version | type == "string" and test("^[a-f0-9]{40}$")) and
    (.logging.Type == "json-file" or .logging.Type == "awslogs") and
    (.logging.Config | type == "object" and all(to_entries[];
      (.key | test("^[a-z0-9-]+$")) and
      (.value | type == "string" and (test("[\\t\\r\\n]") | not))))
  ' >/dev/null <<<"$1"
}

write_state() {
  local temporary
  temporary="$(mktemp "$state_dir/.releases.XXXXXX")" || return 1
  if ! jq -n --argjson current "$1" --argjson previous "$2" \
      '{current: $current, previous: $previous}' >"$temporary"; then
    rm -f "$temporary"
    return 1
  fi
  chmod 0600 "$temporary" || { rm -f "$temporary"; return 1; }
  mv -f "$temporary" "$state_file" || { rm -f "$temporary"; return 1; }
}

health_matches() {
  curl -fs --max-time 3 http://127.0.0.1/health \
    | jq -e '.status == "healthy"' >/dev/null \
    && curl -fs --max-time 3 http://127.0.0.1/version \
    | jq -e --arg version "$1" '.service == "cloudship" and .version == $version' >/dev/null
}

wait_healthy() {
  local attempt attempt_limit="${2:-30}"
  for ((attempt=1; attempt<=attempt_limit; attempt++)); do
    if health_matches "$1"; then return 0; fi
    sleep 2
  done
  return 1
}

verify_recorded_image() {
  local ref expected observed
  ref="$(jq -r '.image' <<<"$1")" || return 1
  expected="$(jq -r '.version' <<<"$1")" || return 1
  if ! observed="$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$ref" 2>/dev/null)"; then
    docker pull "$ref" >/dev/null || return 1
    observed="$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$ref")" || return 1
  fi
  [[ "$observed" == "$expected" ]]
}

# Reject damaged recovery data before changing a running container.
if [[ -f "$state_file" ]]; then
  if ! jq -e 'type == "object" and has("current") and has("previous")' "$state_file" >/dev/null; then
    echo "Invalid release state; application was not changed." >&2
    exit 1
  fi
  current="$(jq -c '.current' "$state_file")"
  previous="$(jq -c '.previous' "$state_file")"
  for record in "$current" "$previous"; do
    if [[ "$record" != null ]] && ! valid_release "$record"; then
      echo "Invalid recorded release; application was not changed." >&2
      exit 1
    fi
  done
fi

# Adopt the actual healthy Phase 4 container, rather than trusting a stale record.
if details="$(docker container inspect cloudship 2>/dev/null)"; then
  live="$(jq -c '.[0] | {image: .Config.Image,
    version: ([.Config.Env[]? | select(startswith("APP_VERSION=")) | ltrimstr("APP_VERSION=")][0] // ""),
    logging: .HostConfig.LogConfig}' <<<"$details")"
  if ! valid_release "$live"; then
    echo "Refusing to replace an unrecognized container named cloudship." >&2
    exit 1
  fi
  live_version="$(jq -r '.version' <<<"$live")"
  live_image="$(jq -r '.image' <<<"$live")"
  live_revision="$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$live_image")"
  if [[ "$live_revision" != "$live_version" ]]; then
    echo "Existing container's image and version disagree; it was not replaced." >&2
    exit 1
  fi
  if jq -e '.[0].State.Running == true' >/dev/null <<<"$details"; then
    if wait_healthy "$live_version" 3; then
      if [[ "$current" != null && "$(jq -Sc . <<<"$current")" != "$(jq -Sc . <<<"$live")" ]]; then
        previous="$current"
      fi
      current="$live"
      baseline_healthy=true
    elif [[ "$current" == null \
        || "$(jq -r '.image' <<<"$current")" != "$live_image" \
        || "$(jq -r '.version' <<<"$current")" != "$live_version" ]]; then
      echo "Running release could not be verified or reconciled; application was not changed." >&2
      exit 1
    fi
  fi
else
  # An inspection error is not proof that the container does not exist.
  remaining="$(docker container ls --all --filter 'name=^/cloudship$' --format '{{.Names}}')"
  if [[ -n "$remaining" ]]; then
    echo "Could not inspect the existing CloudShip container; application was not changed." >&2
    exit 1
  fi
fi
# Validate only the selected recovery target, not unused historical images.
if [[ "$current" != null ]] && ! verify_recorded_image "$current"; then
  echo "Recorded image and revision do not agree; application was not changed." >&2
  exit 1
fi
write_state "$current" "$previous"
if [[ "$mode" == unhealthy-demo && "$baseline_healthy" != true ]]; then
  echo "Failure demonstration requires a currently healthy baseline." >&2
  exit 1
fi

# Pull and verify before stopping anything; a missing image leaves service intact.
docker pull "$image_ref"
revision="$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$image_ref")"
if [[ "$revision" != "$version" ]]; then
  echo "Image revision does not match the requested commit." >&2
  exit 1
fi

# On EC2 use the existing IAM-backed CloudWatch group; local runs keep bounded files.
config_file="${CLOUDSHIP_CONFIG_FILE:-/etc/cloudship.env}"
driver="${CLOUDSHIP_LOG_DRIVER:-}"
if [[ -z "$driver" ]]; then
  if [[ -f "$config_file" ]]; then driver=awslogs; else driver=json-file; fi
fi
if [[ "$driver" == awslogs ]]; then
  source "$config_file"
  if [[ "${AWS_REGION:-}" != ap-southeast-2 || ! "${CLOUDWATCH_LOG_GROUP:-}" =~ ^/[A-Za-z0-9_./#-]+$ ]]; then
    echo "Invalid CloudWatch host configuration." >&2
    exit 1
  fi
  logging="$(jq -nc --arg region "$AWS_REGION" --arg group "$CLOUDWATCH_LOG_GROUP" \
    --arg stream "cloudship/$version/$(date +%s)-$$" \
    '{Type:"awslogs",Config:{"awslogs-region":$region,"awslogs-group":$group,
      "awslogs-stream":$stream,"awslogs-create-group":"false","awslogs-create-stream":"true"}}')"
elif [[ "$driver" == json-file ]]; then
  logging='{"Type":"json-file","Config":{"max-size":"10m","max-file":"3"}}'
else
  echo "Unsupported logging driver." >&2
  exit 1
fi
candidate="$(jq -nc --arg image "$image_ref" --arg version "$version" --argjson logging "$logging" \
  '{image:$image,version:$version,logging:$logging}')"

start_release() {
  local release="$1" release_mode="$2" ref release_version log_driver option_key option_value
  local -a log_arguments=()
  ref="$(jq -r '.image' <<<"$release")" || return 1
  release_version="$(jq -r '.version' <<<"$release")" || return 1
  log_driver="$(jq -r '.logging.Type' <<<"$release")" || return 1
  while IFS=$'\t' read -r option_key option_value; do
    log_arguments+=(--log-opt "$option_key=$option_value")
  done < <(jq -r '.logging.Config | to_entries[] | [.key,.value] | @tsv' <<<"$release")
  local unhealthy=false
  if [[ "$release_mode" == unhealthy-demo ]]; then unhealthy=true; fi
  docker run --detach --name cloudship --restart unless-stopped --publish 80:8000 \
    --label com.cloudship.managed=true --env "APP_VERSION=$release_version" \
    --env "ALLOW_FAILURE_DEMO=$unhealthy" --env "SIMULATE_UNHEALTHY=$unhealthy" \
    --log-driver "$log_driver" "${log_arguments[@]}" "$ref" >/dev/null || return 1
}

remove_current() {
  if docker container inspect cloudship >/dev/null 2>&1; then
    docker stop --time 10 cloudship >/dev/null || return 1
    docker rm cloudship >/dev/null || return 1
  fi
}

force_remove() {
  if docker container inspect cloudship >/dev/null 2>&1; then
    docker rm --force cloudship >/dev/null || return 1
  fi
}

if remove_current && start_release "$candidate" "$mode" && wait_healthy "$version"; then
  next_previous="$current"
  if [[ "$(jq -Sc . <<<"$current")" == "$(jq -Sc . <<<"$candidate")" ]]; then next_previous="$previous"; fi
  if write_state "$candidate" "$next_previous"; then
    echo "Deployment succeeded: $version"
    exit 0
  fi
  echo "Verified candidate could not be recorded; restoring the previous release." >&2
fi

echo "Candidate deployment failed: $version" >&2
# Retain bounded raw logs privately; never send client access logs to Actions.
diagnostic_file="$state_dir/failed-$version-$(date +%s)-$$.log"
if { docker logs --tail 50 cloudship 2>&1 | head -c 16384 >"$diagnostic_file"; } 2>/dev/null; then
  chmod 0600 "$diagnostic_file" 2>/dev/null || true
  echo "Candidate diagnostics retained privately on the host." >&2
else
  echo "Diagnostic storage unavailable; continuing recovery." >&2
fi
if [[ "$current" != null ]]; then
  rollback_version="$(jq -r '.version' <<<"$current")"
  echo "Restoring previous verified release: $rollback_version" >&2
  if force_remove && start_release "$current" healthy && wait_healthy "$rollback_version"; then
    echo "Rollback succeeded: $rollback_version" >&2
  else
    echo "ROLLBACK FAILED: operator recovery is required." >&2
  fi
else
  force_remove || true
  echo "First deployment failed; no previous verified release exists." >&2
fi
# A recovered service does not turn the rejected deployment into success.
exit 1
