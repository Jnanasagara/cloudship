"""Validate the real SSM transport against its external AWS CLI boundary."""

import json
from pathlib import Path
import shlex
import subprocess

import pytest

from scripts import deploy_ssm


@pytest.fixture
def transport(monkeypatch):
    """Capture actual JSON requests while replacing only the AWS CLI process."""
    values = {
        "AWS_REGION": "ap-southeast-2",
        "EC2_INSTANCE_ID": "i-" + "1" * 17,
        "IMAGE_REF": "ghcr.io/jnanasagara/cloudship@sha256:" + "a" * 64,
        "APP_VERSION": "b" * 40,
        "GITHUB_EVENT_NAME": "workflow_dispatch",
        "GITHUB_REF": "refs/heads/main",
        "SIMULATE_UNHEALTHY": "false",
    }
    for key, value in values.items():
        monkeypatch.setenv(key, value)
    requests = []
    results = [{"Status": "Success", "ResponseCode": 0}]

    def cli(arguments, **kwargs):
        if "send-command" in arguments:
            source = arguments[arguments.index("--cli-input-json") + 1]
            requests.append(json.loads(Path(source.removeprefix("file://")).read_text()))
            result = {"Command": {"CommandId": "00000000-0000-0000-0000-000000000000"}}
        else:
            result = results.pop(0)
            if result is None:
                return subprocess.CompletedProcess(arguments, 1, "", "InvocationDoesNotExist")
        return subprocess.CompletedProcess(arguments, 0, json.dumps(result), "")

    monkeypatch.setattr(deploy_ssm.subprocess, "run", cli)
    monkeypatch.setattr(deploy_ssm.time, "sleep", lambda seconds: None)
    return requests, results


def test_healthy_transport_waits_for_propagation_and_requires_success(transport):
    requests, results = transport
    results[:] = [None, {"Status": "InProgress"}, {"Status": "Success", "ResponseCode": 0}]
    deploy_ssm.main()
    assert requests[0]["InstanceIds"] == ["i-" + "1" * 17]
    assert requests[0]["DocumentName"] == "AWS-RunShellScript"
    assert results == []


@pytest.mark.parametrize("event,ref", [("push", "refs/heads/main"), ("workflow_dispatch", "refs/heads/other")])
def test_unhealthy_demo_is_rejected_outside_manual_main(monkeypatch, transport, event, ref):
    requests, _ = transport
    monkeypatch.setenv("SIMULATE_UNHEALTHY", "true")
    monkeypatch.setenv("GITHUB_EVENT_NAME", event)
    monkeypatch.setenv("GITHUB_REF", ref)
    with pytest.raises(ValueError):
        deploy_ssm.main()
    assert requests == []


def test_manual_demo_payload_explicitly_authorizes_unhealthy_mode(monkeypatch, transport):
    requests, _ = transport
    monkeypatch.setenv("SIMULATE_UNHEALTHY", "true")
    deploy_ssm.main()
    command = shlex.split(requests[0]["Parameters"]["commands"][-1])
    assert command[0] == "CLOUDSHIP_ALLOW_FAILURE_DEMO=true"
    assert command[-1] == "unhealthy-demo"


@pytest.mark.parametrize("status,code", [("Failed", 1), ("TimedOut", -1), ("Success", 1)])
def test_unsuccessful_remote_execution_never_reports_success(transport, status, code):
    _, results = transport
    results[:] = [{"Status": status, "ResponseCode": code}]
    with pytest.raises(RuntimeError):
        deploy_ssm.main()


def test_invalid_image_is_rejected_before_sending_commands(monkeypatch, transport):
    requests, _ = transport
    monkeypatch.setenv("IMAGE_REF", "ghcr.io/another/project:latest; bad")
    with pytest.raises(ValueError):
        deploy_ssm.main()
    assert requests == []


def test_remote_application_output_is_not_republished_in_actions(transport, capsys):
    _, results = transport
    sentinel = '198.51.100.7 GET /private-demo-path'
    results[:] = [{"Status": "Failed", "ResponseCode": 1,
                  "StandardOutputContent": sentinel,
                  "StandardErrorContent": sentinel + "\nRollback succeeded: " + "a" * 40}]
    with pytest.raises(RuntimeError):
        deploy_ssm.main()
    output = capsys.readouterr()
    assert sentinel not in output.out + output.err
    assert "Rollback succeeded: " + "a" * 40 in output.out + output.err
