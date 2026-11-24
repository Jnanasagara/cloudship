"""Run real Bash recovery logic; only Docker, HTTP and sleep cross test boundaries."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import pytest

ROOT = Path(__file__).resolve().parents[1]
A = "ghcr.io/jnanasagara/cloudship@sha256:" + "a" * 64
B = "ghcr.io/jnanasagara/cloudship@sha256:" + "b" * 64
OLD = "ghcr.io/jnanasagara/cloudship@sha256:" + "c" * 64
LOGGING = {"Type": "json-file", "Config": {"max-size": "10m", "max-file": "3"}}
pytestmark = pytest.mark.skipif(
    os.name == "nt" or not hasattr(os, "geteuid") or os.geteuid() != 0
    or not all(shutil.which(tool) for tool in ("bash", "jq", "flock")),
    reason="Privileged Bash suite runs in the Linux test container / CI sudo step.",
)


def release(image, version):
    return {"image": image, "version": version, "logging": LOGGING}


@pytest.fixture
def host(tmp_path):
    """Provide a private host state and executable external-tool substitutes."""
    binary_dir = tmp_path / "bin"
    binary_dir.mkdir()
    boundary = (ROOT / "tests/fixtures/deployment_tools.py").read_text()
    for name in ("docker", "curl", "sleep", "date"):
        executable = binary_dir / name
        executable.write_text(f"#!{sys.executable}\n" + boundary)
        executable.chmod(0o755)
    runtime_path = tmp_path / "runtime.json"
    state_dir = tmp_path / "releases"
    state_dir.mkdir()
    config_path = tmp_path / "host.env"
    config_path.write_text("AWS_REGION='ap-southeast-2'\nCLOUDWATCH_LOG_GROUP='/cloudship/dev/app'\n")
    initial = {
        "candidate": B,
        "images": {A: "a" * 40, B: "b" * 40, OLD: "c" * 40},
        "container": {
            "Config": {"Image": A, "Env": ["APP_VERSION=" + "a" * 40]},
            "HostConfig": {"LogConfig": LOGGING},
            "State": {"Running": True},
        },
    }

    def run(*, scenario=None, image=B, version="b" * 40, mode=None, allow_demo=False, log_driver="json-file"):
        runtime_path.write_text(json.dumps({**initial, **(scenario or {})}))
        env = {
            **os.environ,
            "PATH": str(binary_dir) + os.pathsep + os.environ["PATH"],
            "FAKE_RUNTIME_STATE": str(runtime_path),
            "CLOUDSHIP_STATE_DIR": str(state_dir),
            "CLOUDSHIP_ALLOW_FAILURE_DEMO": "true" if allow_demo else "false",
            "CLOUDSHIP_LOG_DRIVER": log_driver,
            "CLOUDSHIP_CONFIG_FILE": str(config_path),
        }
        command = ["bash", str(ROOT / "scripts/deploy.sh"), image, version]
        if mode:
            command.append(mode)
        result = subprocess.run(command, env=env, text=True, capture_output=True, timeout=45)
        return result, json.loads(runtime_path.read_text())

    return run, state_dir


def read_releases(directory):
    path = directory / "releases.json"
    assert path.exists(), "The last verified release must be persisted."
    return json.loads(path.read_text())


def test_failed_candidate_restores_actual_healthy_image_and_reports_failure(host):
    run, directory = host
    result, runtime = run(scenario={"bad_candidate": True})
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A, result.stdout + result.stderr
    assert runtime["container"]["State"]["Running"]
    assert read_releases(directory)["current"]["version"] == "a" * 40


def test_success_updates_current_and_previous_as_one_record(host):
    run, directory = host
    result, runtime = run()
    assert result.returncode == 0, result.stdout + result.stderr
    assert runtime["container"]["Config"]["Image"] == B
    saved = read_releases(directory)
    assert saved["current"]["image"] == B
    assert saved["previous"]["image"] == A
    assert saved["previous"]["logging"] == LOGGING
    assert directory.joinpath("releases.json").stat().st_mode & 0o777 == 0o600


def test_first_deploy_failure_removes_failed_candidate_without_claiming_recovery(host):
    run, directory = host
    result, runtime = run(scenario={"container": None, "bad_candidate": True})
    assert result.returncode != 0
    assert runtime["container"] is None
    assert read_releases(directory)["current"] is None


def test_missing_candidate_leaves_existing_service_running(host):
    run, _ = host
    result, runtime = run(scenario={"missing_candidate": True})
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A
    assert runtime["container"]["State"]["Running"]


def test_failed_container_start_recovers_previous_release(host):
    run, _ = host
    result, runtime = run(scenario={"candidate_start_fails": True})
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A
    assert runtime["container"]["State"]["Running"]


def test_failed_rollback_preserves_last_verified_state_and_fails(host):
    run, directory = host
    result, runtime = run(scenario={"bad_candidate": True, "rollback_start_fails": True})
    assert result.returncode != 0
    assert not runtime.get("container") or not runtime["container"]["State"]["Running"]
    assert read_releases(directory)["current"]["image"] == A


def test_corrupt_state_is_rejected_before_touching_the_running_application(host):
    run, directory = host
    (directory / "releases.json").write_text("not-json")
    result, runtime = run()
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A


def test_live_verified_release_wins_over_stale_record_for_rollback(host):
    run, directory = host
    (directory / "releases.json").write_text(json.dumps({"current": release(OLD, "c" * 40), "previous": None}))
    result, runtime = run(scenario={"bad_candidate": True})
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A
    assert read_releases(directory)["current"]["image"] == A


def test_unhealthy_demo_requires_explicit_authorization(host):
    run, _ = host
    result, runtime = run(mode="unhealthy-demo")
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A


def test_explicit_demo_sets_bad_health_then_restores_healthy_environment(host):
    run, _ = host
    result, runtime = run(mode="unhealthy-demo", allow_demo=True)
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A
    env = dict(item.split("=", 1) for item in runtime["container"]["Config"]["Env"])
    assert env["ALLOW_FAILURE_DEMO"] == "false"
    assert env["SIMULATE_UNHEALTHY"] == "false"


def test_rollback_restores_previous_logging_configuration(host):
    run, directory = host
    result, runtime = run(scenario={"bad_candidate": True}, log_driver="awslogs")
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A
    assert runtime["container"]["HostConfig"]["LogConfig"] == LOGGING
    assert read_releases(directory)["current"]["logging"] == LOGGING


def test_cloudwatch_release_uses_existing_group_without_group_creation(host):
    run, directory = host
    result, runtime = run(log_driver="awslogs")
    assert result.returncode == 0, result.stdout + result.stderr
    config = runtime["container"]["HostConfig"]["LogConfig"]
    assert config["Type"] == "awslogs"
    assert config["Config"]["awslogs-group"] == "/cloudship/dev/app"
    assert config["Config"]["awslogs-region"] == "ap-southeast-2"
    assert config["Config"]["awslogs-create-group"] == "false"
    assert read_releases(directory)["current"]["logging"] == config


@pytest.mark.parametrize("stale", [False, True])
def test_transient_adoption_probe_does_not_lose_real_recovery_target(host, stale):
    run, directory = host
    if stale:
        (directory / "releases.json").write_text(json.dumps({"current": release(OLD, "c" * 40), "previous": None}))
    result, runtime = run(scenario={"health_failures": 1, "bad_candidate": True})
    assert result.returncode != 0
    assert runtime.get("container") and runtime["container"]["Config"]["Image"] == A
    assert read_releases(directory)["current"]["version"] == "a" * 40


def test_unverifiable_running_release_is_not_replaced_without_matching_record(host):
    run, directory = host
    result, runtime = run(scenario={"unhealthy_existing": True})
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A
    assert not (directory / "releases.json").exists()


def test_inspection_failure_is_not_treated_as_an_absent_container(host):
    run, directory = host
    result, runtime = run(scenario={"inspect_error": True})
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A
    assert not (directory / "releases.json").exists()


@pytest.mark.parametrize("container", [None, {"Config": {"Image": A, "Env": ["APP_VERSION=" + "a" * 40]}, "HostConfig": {"LogConfig": LOGGING}, "State": {"Running": False}}])
def test_crossed_saved_digest_and_version_are_rejected_before_deployment(host, container):
    run, directory = host
    (directory / "releases.json").write_text(json.dumps({"current": release(A, "c" * 40), "previous": None}))
    result, runtime = run(scenario={"container": container, "bad_candidate": True})
    assert result.returncode != 0
    assert runtime["container"] == container


def test_raw_application_diagnostics_stay_private_on_host(host):
    run, directory = host
    sentinel = '198.51.100.7:4812 - "GET /private-demo-path HTTP/1.1" 503'
    result, _ = run(scenario={"bad_candidate": True, "diagnostic": sentinel})
    assert result.returncode != 0
    assert sentinel not in result.stdout + result.stderr
    logs = list(directory.glob("failed-*.log"))
    assert len(logs) == 1
    assert sentinel in logs[0].read_text()
    assert logs[0].stat().st_mode & 0o777 == 0o600


def test_unavailable_diagnostic_storage_never_prevents_rollback(host):
    run, _ = host
    result, runtime = run(scenario={"bad_candidate": True, "diagnostics_unavailable": True})
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A
    assert runtime["container"]["State"]["Running"]


def test_removed_unused_history_image_does_not_block_healthy_update(host):
    run, directory = host
    (directory / "releases.json").write_text(json.dumps({"current": release(A, "a" * 40), "previous": release(OLD, "c" * 40)}))
    result, runtime = run(scenario={"images": {A: "a" * 40, B: "b" * 40}})
    assert result.returncode == 0, result.stdout + result.stderr
    assert runtime["container"]["Config"]["Image"] == B
    assert read_releases(directory)["previous"]["image"] == A


@pytest.mark.parametrize("image,version", [(B + ";bad", "b" * 40), (B, "not-a-sha")])
def test_invalid_release_never_replaces_the_application(host, image, version):
    run, _ = host
    result, runtime = run(image=image, version=version)
    assert result.returncode != 0
    assert runtime["container"]["Config"]["Image"] == A
