"""Send the reviewed deployment script through AWS Systems Manager."""

import base64
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import time


def aws(*arguments: str, allow_missing: bool = False) -> dict | None:
    """Call AWS without shell interpolation; tolerate initial SSM propagation."""
    result = subprocess.run(
        [
            "aws",
            "--region", "ap-southeast-2",
            "--output", "json",
            "--no-cli-pager",
            "--cli-connect-timeout", "10",
            "--cli-read-timeout", "20",
            *arguments,
        ],
        capture_output=True,
        text=True,
        timeout=45,
        check=False,
    )

    if result.returncode != 0:
        if allow_missing and "InvocationDoesNotExist" in result.stderr:
            return None
        raise RuntimeError(result.stderr.strip() or "AWS CLI request failed.")

    return json.loads(result.stdout)


def main() -> None:
    """Validate inputs, submit one deployment, and require confirmed success."""
    region = os.environ.get("AWS_REGION", "")
    instance_id = os.environ.get("EC2_INSTANCE_ID", "")
    image_ref = os.environ.get("IMAGE_REF", "")
    version = os.environ.get("APP_VERSION", "")

    if region != "ap-southeast-2":
        raise ValueError("AWS_REGION must be ap-southeast-2.")
    if not re.fullmatch(r"i-[a-f0-9]{17}", instance_id):
        raise ValueError("Invalid EC2_INSTANCE_ID.")
    if not re.fullmatch(
        r"ghcr\.io/jnanasagara/cloudship@sha256:[a-f0-9]{64}", image_ref
    ):
        raise ValueError("IMAGE_REF must contain our exact image digest.")
    if not re.fullmatch(r"[a-f0-9]{40}", version):
        raise ValueError("APP_VERSION must be a full Git commit SHA.")

    script = Path(__file__).with_name("deploy.sh").read_bytes()
    if not script.startswith(b"#!/usr/bin/env bash\n") or b"\r" in script:
        raise ValueError("deploy.sh must have its shebang and LF line endings.")

    encoded = base64.b64encode(script).decode("ascii")

    # A unique temporary script prevents another deployment replacing this payload.
    commands = [
        "set -eu",
        "install -d -m 0755 /opt/cloudship/bin",
        "script_path=$(mktemp /opt/cloudship/bin/.deploy.XXXXXX)",
        """trap 'rm -f "$script_path"' EXIT""",
        f"printf '%s' {shlex.quote(encoded)} | base64 --decode > \"$script_path\"",
        'chmod 0700 "$script_path"',
        'bash -n "$script_path"',
        'install -m 0700 "$script_path" /opt/cloudship/bin/deploy.sh',
        f'bash "$script_path" {shlex.quote(image_ref)} {shlex.quote(version)}',
    ]

    payload = {
        "DocumentName": "AWS-RunShellScript",
        "InstanceIds": [instance_id],
        "Comment": f"CloudShip deployment {version}",
        "TimeoutSeconds": 120,
        "Parameters": {
            "commands": commands,
            "executionTimeout": ["600"],
        },
    }

    # A JSON file avoids command-line quoting differences between operating systems.
    with tempfile.TemporaryDirectory(prefix="cloudship-ssm-") as directory:
        request_path = Path(directory) / "request.json"
        request_path.write_text(json.dumps(payload), encoding="utf-8")
        response = aws(
            "ssm", "send-command",
            "--cli-input-json", f"file://{request_path.as_posix()}",
        )

    command_id = response["Command"]["CommandId"]
    print(f"SSM command submitted: {command_id}", flush=True)

    # Allow delivery, execution, and a short eventual-consistency margin.
    deadline = time.monotonic() + 780
    pending = {"Pending", "InProgress", "Delayed", "Cancelling"}

    while time.monotonic() < deadline:
        result = aws(
            "ssm", "get-command-invocation",
            "--command-id", command_id,
            "--instance-id", instance_id,
            allow_missing=True,
        )

        if result is not None and result["Status"] not in pending:
            print(result.get("StandardOutputContent", ""), flush=True)
            print(result.get("StandardErrorContent", ""), file=sys.stderr)

            if result["Status"] == "Success" and result["ResponseCode"] == 0:
                print("CloudShip deployment verified.")
                return

            raise RuntimeError(
                f"Deployment failed: {result['Status']}, "
                f"exit code {result['ResponseCode']}."
            )

        time.sleep(5)

    raise RuntimeError(
        f"Stopped waiting for SSM command {command_id}; "
        "its remote execution status must be checked before retrying."
    )


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)