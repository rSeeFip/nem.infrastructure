import argparse
import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "readonly-recovery-preflight.py"
spec = importlib.util.spec_from_file_location("readonly_recovery_preflight", SCRIPT)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load {SCRIPT}")
preflight = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = preflight
spec.loader.exec_module(preflight)


def args(**overrides):
    values = {
        "context": "nemk3s",
        "namespace": ["nem-apps"],
        "backup_namespace": "nem-apps",
        "backup_deployment": None,
        "backup_cronjob": None,
        "backup_job": None,
        "backend_metadata_resource": None,
        "approved_metadata_resource": None,
        "expected_node": None,
        "expected_node_uid": None,
        "kubectl": "fixture-kubectl",
        "timeout_seconds": 3,
        "preflight_deadline_seconds": 30,
        "json": True,
    }
    values.update(overrides)
    return argparse.Namespace(**values)


def key(*parts):
    return ("fixture-kubectl", "--context", "nemk3s", "--request-timeout=3s", *parts)


class FakeKubectl:
    def __init__(self, responses):
        self.responses, self.calls = responses, []

    def __call__(self, command, timeout_seconds):
        self.calls.append((list(command), timeout_seconds))
        response = self.responses.get(
            tuple(part for part in command if part not in {"-o", "json"})
        )
        if isinstance(response, BaseException):
            raise response
        if response is None:
            return subprocess.CompletedProcess(command, 1, "", "not found")
        return (
            response
            if isinstance(response, subprocess.CompletedProcess)
            else subprocess.CompletedProcess(command, 0, json.dumps(response), "")
        )


def nodes():
    return {"items": [{"metadata": {"name": "nemk3s", "uid": "node-uid"}}]}


def base():
    return {
        key("get", "nodes"): nodes(),
        key("get", "namespace", "nem-apps"): {"status": {"phase": "Active"}},
    }


class ReadonlyRecoveryPreflightTests(unittest.TestCase):
    def test_unknown_fails_closed_without_configured_workload_or_backend(self):
        checks = {
            check.name: check
            for check in preflight.run_preflight(args(), FakeKubectl(base()))
        }
        self.assertEqual("UNKNOWN", checks["backup_workload_metadata"].status)
        self.assertEqual("UNKNOWN", checks["backup_record_metadata"].status)
        self.assertEqual("UNKNOWN", checks["restore_verified"].status)
        with mock.patch.object(
            preflight, "run_preflight", return_value=list(checks.values())
        ):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(
                    2,
                    preflight.main(
                        [
                            "--context",
                            "nemk3s",
                            "--namespace",
                            "nem-apps",
                            "--backup-namespace",
                            "nem-apps",
                        ]
                    ),
                )

    def test_named_job_and_cronjob_metadata_are_not_artifact_evidence(self):
        responses = {
            **base(),
            key("-n", "nem-apps", "get", "cronjob", "nightly-backup"): {
                "metadata": {
                    "name": "nightly-backup",
                    "creationTimestamp": "2026-09-18T00:00:00Z",
                }
            },
            key("-n", "nem-apps", "get", "job", "nightly-backup-1"): {
                "metadata": {
                    "name": "nightly-backup-1",
                    "creationTimestamp": "2026-09-18T00:01:00Z",
                }
            },
        }
        checks = {
            check.name: check
            for check in preflight.run_preflight(
                args(
                    backup_cronjob=["nightly-backup"], backup_job=["nightly-backup-1"]
                ),
                FakeKubectl(responses),
            )
        }
        self.assertEqual("PASS", checks["backup_cronjob:nightly-backup"].status)
        self.assertEqual("PASS", checks["backup_job:nightly-backup-1"].status)
        self.assertEqual("UNKNOWN", checks["backup_record_metadata"].status)

    def test_external_backend_is_test_only_policy_input_and_never_queried(self):
        hypothetical = "records.test-only.example"
        fake = FakeKubectl(base())
        checks = {
            check.name: check
            for check in preflight.run_preflight(
                args(
                    backend_metadata_resource=hypothetical,
                    approved_metadata_resource=[hypothetical],
                ),
                fake,
            )
        }
        self.assertEqual("UNKNOWN", checks["backup_record_metadata"].status)
        self.assertEqual(
            hypothetical, checks["backup_record_metadata"].evidence["resource"]
        )
        self.assertFalse(any(hypothetical in command for command, _ in fake.calls))

    def test_invalid_resources_and_arguments_are_rejected(self):
        for resource in (
            "secrets",
            "secrets.v1",
            "pods",
            "records.test-only.example/--all",
            "records.test-only.example,secret",
        ):
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    preflight.parse_args(
                        [
                            "--context",
                            "c",
                            "--namespace",
                            "n",
                            "--backup-namespace",
                            "b",
                            "--backend-metadata-resource",
                            resource,
                            "--approved-metadata-resource",
                            resource,
                        ]
                    )
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                preflight.parse_args(
                    [
                        "--context",
                        "c",
                        "--namespace",
                        "n",
                        "--backup-namespace",
                        "b",
                        "--backend-metadata-resource",
                        "records.test-only.example",
                    ]
                )
            with self.assertRaises(SystemExit):
                preflight.parse_args(
                    [
                        "--context",
                        "c",
                        "--namespace",
                        "n",
                        "--backup-namespace",
                        "b",
                        "--timeout-seconds",
                        "0",
                    ]
                )

    def test_kubectl_target_arguments_reject_flags_before_any_runner(self):
        invalid_argv = [
            [
                "--context=--raw=/api/v1/secrets",
                "--namespace",
                "n",
                "--backup-namespace",
                "b",
            ],
            [
                "--context",
                "arn:cluster/allowed",
                "--namespace=--raw=/api/v1/secrets",
                "--backup-namespace",
                "b",
            ],
            [
                "--context",
                "arn:cluster/allowed",
                "--namespace",
                "n",
                "--backup-namespace=--raw=/api/v1/secrets",
            ],
            [
                "--context",
                "arn:cluster/allowed",
                "--namespace",
                "n",
                "--backup-namespace",
                "b",
                "--backup-deployment=--raw=/api/v1/secrets",
            ],
        ]
        for argv in invalid_argv:
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    preflight.parse_args(argv)
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                preflight.parse_args(
                    [
                        "--context",
                        "c",
                        "--namespace",
                        "n" * 64,
                        "--backup-namespace",
                        "b",
                    ]
                )

    def test_timeout_duplicate_json_bool_replicas_and_total_deadline_fail_closed(self):
        check = preflight.run_preflight(
            args(),
            FakeKubectl(
                {key("get", "nodes"): subprocess.TimeoutExpired(["kubectl"], 3)}
            ),
        )[0]
        self.assertEqual("command-timeout", check.evidence["error_class"])
        check = preflight.run_preflight(
            args(),
            FakeKubectl(
                {
                    key("get", "nodes"): subprocess.CompletedProcess(
                        [], 0, '{"items":[],"items":[]}', ""
                    )
                }
            ),
        )[0]
        self.assertEqual("invalid-json", check.evidence["error_class"])
        secret_error = subprocess.CompletedProcess(
            [], 1, "token=supersecret", "Authorization: Bearer secret"
        )
        check = preflight.run_preflight(
            args(), FakeKubectl({key("get", "nodes"): secret_error})
        )[0]
        self.assertEqual("kubectl-query-failed", check.evidence["error_class"])
        self.assertNotIn("secret", json.dumps(check.evidence))
        deployment = {
            **base(),
            key("-n", "nem-apps", "get", "deployment", "backup-api"): {
                "spec": {"replicas": 1},
                "status": {"readyReplicas": True},
            },
        }
        checks = {
            check.name: check
            for check in preflight.run_preflight(
                args(backup_deployment="backup-api"), FakeKubectl(deployment)
            )
        }
        self.assertEqual("FAIL", checks["backup_workload"].status)
        fake = FakeKubectl({key("get", "nodes"): nodes()})
        with mock.patch.object(preflight.time, "monotonic", side_effect=[0, 0, 2, 2]):
            checks = preflight.run_preflight(
                args(namespace=["one", "two"], preflight_deadline_seconds=1), fake
            )
        self.assertEqual(1, len(fake.calls))
        self.assertEqual(
            "preflight-deadline-exceeded", checks[1].evidence["error_class"]
        )

    def test_runner_and_commands_are_bounded_readonly_gets(self):
        with mock.patch.object(preflight.subprocess, "run") as run:
            preflight.readonly_runner(["kubectl", "get", "nodes"], 3)
        run.assert_called_once_with(
            ["kubectl", "get", "nodes"],
            capture_output=True,
            check=False,
            text=True,
            timeout=3,
        )
        fake = FakeKubectl(base())
        preflight.run_preflight(
            args(expected_node="nemk3s", expected_node_uid="node-uid"), fake
        )
        forbidden = {
            "apply",
            "create",
            "delete",
            "patch",
            "replace",
            "restore",
            "exec",
            "rollout",
            "scale",
            "-A",
        }
        for command, _ in fake.calls:
            self.assertIn("--context", command)
            self.assertIn("get", command)
            self.assertTrue(forbidden.isdisjoint(command), command)


if __name__ == "__main__":
    unittest.main()
