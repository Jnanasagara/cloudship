"""Stateful external CLI boundary for exercising the actual Bash deployment."""

import json
import os
from pathlib import Path
import sys

path = Path(os.environ["FAKE_RUNTIME_STATE"])
state = json.loads(path.read_text())
tool = Path(sys.argv[0]).name
args = sys.argv[1:]


def save():
    path.write_text(json.dumps(state))


def fail(message, code=1):
    print(message, file=sys.stderr)
    sys.exit(code)


if tool == "sleep":
    sys.exit(0)
if tool == "date":
    if state.get("diagnostics_unavailable"):
        directory = Path(os.environ["CLOUDSHIP_STATE_DIR"])
        if directory.exists():
            directory.rename(directory.with_name(directory.name + ".unavailable"))
    print("123456")
    sys.exit(0)
if tool == "curl":
    container = state.get("container")
    if not container or not container["State"]["Running"]:
        fail("Connection refused", 7)
    env = dict(item.split("=", 1) for item in container["Config"]["Env"])
    unhealthy = env.get("SIMULATE_UNHEALTHY") == "true" or (
        state.get("bad_candidate") and container["Config"]["Image"] == state["candidate"]
    )
    if args[-1].endswith("/health"):
        if state.get("health_failures", 0) > 0:
            state["health_failures"] -= 1
            save()
            fail("Transient HTTP failure", 22)
        if state.get("unhealthy_existing") and container["Config"]["Image"] != state["candidate"]:
            fail("Existing release cannot be verified", 22)
        if unhealthy:
            fail("HTTP 503", 22)
        print(json.dumps({"status": "healthy"}))
    else:
        print(json.dumps({"service": "cloudship", "version": env["APP_VERSION"]}))
    sys.exit(0)

if args[0] == "info":
    if state.get("docker_denied"):
        fail("Cannot connect to Docker daemon")
elif args[0] == "pull":
    if state.get("missing_candidate") and args[-1] == state["candidate"]:
        fail("Manifest unknown")
    if args[-1] not in state["images"]:
        fail("Image missing")
elif args[:2] == ["image", "inspect"]:
    version = state["images"].get(args[-1])
    if not version:
        fail("Image missing")
    if "--format" in args:
        print(version)
    else:
        print(json.dumps([{"Config": {"Labels": {"org.opencontainers.image.revision": version}}}]))
elif args[:2] == ["container", "inspect"] or args[0] == "inspect":
    if state.get("inspect_error"):
        fail("Docker inspect failed")
    if not state.get("container"):
        fail("No such container")
    print(json.dumps([state["container"]]))
elif args[:2] == ["container", "ls"]:
    if state.get("container"):
        print("cloudship")
elif args[0] == "stop":
    state["container"]["State"]["Running"] = False
    save()
elif args[0] == "rm":
    state["container"] = None
    save()
elif args[0] == "run":
    env, options = [], {}
    driver = "json-file"
    for index, arg in enumerate(args[:-1]):
        if arg == "--env":
            env.append(args[index + 1])
        elif arg == "--log-opt":
            key, value = args[index + 1].split("=", 1)
            options[key] = value
        elif arg == "--log-driver":
            driver = args[index + 1]
    image = args[-1]
    # Characterize the actual AL2023 host's driver: it creates streams by default
    # and rejected this explicit option during the live compatibility trial.
    if driver == "awslogs" and "awslogs-create-stream" in options:
        fail("unknown log opt 'awslogs-create-stream' for awslogs log driver", 125)
    failed = (state.get("candidate_start_fails") and image == state["candidate"]) or (
        state.get("rollback_start_fails") and image != state["candidate"]
    )
    state["container"] = {
        "Config": {"Image": image, "Env": env},
        "HostConfig": {"LogConfig": {"Type": driver, "Config": options}},
        "State": {"Running": not failed},
    }
    save()
    if failed:
        fail("Port allocation or container start failed", 125)
    print("test-container")
elif args[0] == "logs":
    print(state.get("diagnostic", "Application diagnostic log"))
else:
    fail("Unsupported fake Docker operation: " + repr(args))
