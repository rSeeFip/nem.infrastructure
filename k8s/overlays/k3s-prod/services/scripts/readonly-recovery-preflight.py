#!/usr/bin/env python3
"""Fail-closed, read-only recovery evidence inventory for explicit Kubernetes targets."""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any, Callable, Sequence


@dataclass(frozen=True)
class Check:
    name: str
    status: str
    message: str
    evidence: dict[str, object]


Runner = Callable[[Sequence[str], int], subprocess.CompletedProcess[str]]
DNS_NAME_PATTERN = re.compile(r"^[a-z0-9](?:[-a-z0-9]*[a-z0-9])?$")
QUALIFIED_RESOURCE_PATTERN = re.compile(
    r"^[a-z0-9](?:[-a-z0-9]*[a-z0-9])?(?:\.[a-z0-9](?:[-a-z0-9]*[a-z0-9])?)+$"
)
CORE_OR_SECRET_RESOURCE_NAMES = frozenset(
    {
        "secret",
        "secrets",
        "configmap",
        "configmaps",
        "pod",
        "pods",
        "service",
        "services",
        "node",
        "nodes",
        "namespace",
        "namespaces",
        "deployment",
        "deployments",
        "job",
        "jobs",
        "cronjob",
        "cronjobs",
        "persistentvolumeclaim",
        "persistentvolumeclaims",
    }
)


def readonly_runner(
    command: Sequence[str], timeout_seconds: int
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, capture_output=True, check=False, text=True, timeout=timeout_seconds
    )


def bounded_timeout(value: str) -> int:
    timeout = int(value)
    if not 1 <= timeout <= 60:
        raise argparse.ArgumentTypeError("must be between 1 and 60 seconds")
    return timeout


def bounded_deadline(value: str) -> int:
    deadline = int(value)
    if not 1 <= deadline <= 300:
        raise argparse.ArgumentTypeError("must be between 1 and 300 seconds")
    return deadline


def nonsecret_qualified_resource(value: str) -> str:
    resource_name = value.split(".", 1)[0]
    if (
        not QUALIFIED_RESOURCE_PATTERN.fullmatch(value)
        or resource_name in CORE_OR_SECRET_RESOURCE_NAMES
    ):
        raise argparse.ArgumentTypeError(
            "must be a single qualified non-core, non-secret resource"
        )
    return value


def dns_name(value: str) -> str:
    if len(value) > 63 or not DNS_NAME_PATTERN.fullmatch(value):
        raise argparse.ArgumentTypeError("must be a single DNS-compatible name")
    return value


def kube_context(value: str) -> str:
    if not value or value.startswith("-"):
        raise argparse.ArgumentTypeError("must be a non-flag Kubernetes context name")
    return value


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--context", required=True, type=kube_context)
    parser.add_argument(
        "--namespace",
        action="append",
        required=True,
        type=dns_name,
        help="Repeat for each intended namespace",
    )
    parser.add_argument("--backup-namespace", required=True, type=dns_name)
    parser.add_argument(
        "--backup-deployment",
        type=dns_name,
        help="Explicit backup deployment name; never inferred",
    )
    parser.add_argument("--backup-cronjob", action="append", type=dns_name)
    parser.add_argument("--backup-job", action="append", type=dns_name)
    parser.add_argument(
        "--backend-metadata-resource",
        type=nonsecret_qualified_resource,
        help="Approved external metadata resource; adapter remains disabled",
    )
    parser.add_argument(
        "--approved-metadata-resource",
        action="append",
        type=nonsecret_qualified_resource,
    )
    parser.add_argument("--expected-node")
    parser.add_argument("--expected-node-uid")
    parser.add_argument("--kubectl", default="kubectl")
    parser.add_argument("--timeout-seconds", type=bounded_timeout, default=10)
    parser.add_argument(
        "--preflight-deadline-seconds", type=bounded_deadline, default=30
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    if len(set(args.namespace)) != len(args.namespace):
        parser.error("--namespace values must be unique")
    if bool(args.expected_node) != bool(args.expected_node_uid):
        parser.error(
            "--expected-node and --expected-node-uid must be provided together"
        )
    for names, option in (
        (args.backup_cronjob or [], "--backup-cronjob"),
        (args.backup_job or [], "--backup-job"),
        (args.approved_metadata_resource or [], "--approved-metadata-resource"),
    ):
        if len(set(names)) != len(names):
            parser.error(f"{option} values must be unique")
    if args.backend_metadata_resource and args.backend_metadata_resource not in (
        args.approved_metadata_resource or []
    ):
        parser.error(
            "--backend-metadata-resource must appear in operator-supplied --approved-metadata-resource"
        )
    if args.approved_metadata_resource and not args.backend_metadata_resource:
        parser.error(
            "--approved-metadata-resource requires --backend-metadata-resource"
        )
    return args


def run_kubectl(
    args: argparse.Namespace, command: Sequence[str], runner: Runner
) -> tuple[subprocess.CompletedProcess[str] | None, str | None]:
    remaining = args._deadline - time.monotonic()
    if remaining <= 0:
        return None, "preflight-deadline-exceeded"
    wall_timeout = min(args.timeout_seconds, remaining)
    request_timeout = max(1, math.ceil(wall_timeout))
    try:
        return runner(
            [
                args.kubectl,
                "--context",
                args.context,
                f"--request-timeout={request_timeout}s",
                *command,
            ],
            wall_timeout,
        ), None
    except subprocess.TimeoutExpired:
        return None, "command-timeout"
    except FileNotFoundError:
        return None, "kubectl-not-found"
    except OSError:
        return None, "command-unavailable"


def get_json(
    args: argparse.Namespace, command: Sequence[str], runner: Runner
) -> tuple[dict[str, Any] | None, str | None]:
    completed, error = run_kubectl(args, [*command, "-o", "json"], runner)
    if error:
        return None, error
    if completed is None or completed.returncode != 0:
        return None, "kubectl-query-failed"

    def reject_duplicate_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result

    try:
        payload = json.loads(
            completed.stdout, object_pairs_hook=reject_duplicate_object
        )
    except (TypeError, ValueError, json.JSONDecodeError):
        return None, "invalid-json"
    return (
        (payload, None) if isinstance(payload, dict) else (None, "invalid-json-object")
    )


def nested(value: object, path: str) -> tuple[object | None, bool]:
    current: object = value
    for part in path.split("."):
        if not isinstance(current, dict) or part not in current:
            return None, False
        current = current[part]
    return current, True


def check_context(args: argparse.Namespace, runner: Runner) -> Check:
    nodes, error = get_json(args, ["get", "nodes"], runner)
    if nodes is None:
        return Check(
            "context_reachability",
            "FAIL",
            "Explicit context is not readable",
            {"error_class": error},
        )
    items = nodes.get("items")
    if not isinstance(items, list) or not items:
        return Check(
            "context_reachability", "FAIL", "Context returned no readable nodes", {}
        )
    records = []
    for item in items:
        name, has_name = nested(item, "metadata.name")
        uid, has_uid = nested(item, "metadata.uid")
        if (
            not has_name
            or not has_uid
            or not isinstance(name, str)
            or not isinstance(uid, str)
        ):
            return Check(
                "context_reachability", "FAIL", "Node metadata is malformed", {}
            )
        records.append({"name": name, "uid": uid})
    if args.expected_node:
        matching = [
            record
            for record in records
            if record["name"] == args.expected_node
            and record["uid"] == args.expected_node_uid
        ]
        if not matching:
            return Check(
                "context_node_identity",
                "FAIL",
                "Expected node name and UID were not observed",
                {"nodes": records},
            )
        return Check(
            "context_node_identity",
            "PASS",
            "Expected node name and UID were observed",
            {"nodes": matching},
        )
    return Check(
        "context_reachability",
        "PASS",
        "Explicit context returned readable nodes; identity was not pinned",
        {"nodes": records},
    )


def check_namespace(args: argparse.Namespace, namespace: str, runner: Runner) -> Check:
    resource, error = get_json(args, ["get", "namespace", namespace], runner)
    if resource is None:
        return Check(
            f"namespace:{namespace}",
            "FAIL",
            "Namespace cannot be read",
            {"error_class": error},
        )
    phase, present = nested(resource, "status.phase")
    if not present or not isinstance(phase, str):
        return Check(
            f"namespace:{namespace}", "FAIL", "Namespace payload is malformed", {}
        )
    return Check(
        f"namespace:{namespace}",
        "PASS" if phase == "Active" else "UNKNOWN",
        f"Namespace phase is {phase}",
        {},
    )


def check_backup_workload(args: argparse.Namespace, runner: Runner) -> Check:
    if not args.backup_deployment:
        return Check(
            "backup_workload",
            "UNKNOWN",
            "No backup deployment was configured; no workload is inferred",
            {},
        )
    resource, error = get_json(
        args,
        ["-n", args.backup_namespace, "get", "deployment", args.backup_deployment],
        runner,
    )
    if resource is None:
        return Check(
            "backup_workload",
            "FAIL",
            "Configured backup deployment cannot be read",
            {"error_class": error},
        )
    ready, ready_present = nested(resource, "status.readyReplicas")
    desired, desired_present = nested(resource, "spec.replicas")
    if (
        not ready_present
        or not desired_present
        or type(ready) is not int
        or type(desired) is not int
    ):
        return Check(
            "backup_workload",
            "FAIL",
            "Configured backup deployment payload is malformed",
            {},
        )
    status = "PASS" if desired > 0 and ready == desired else "UNKNOWN"
    return Check(
        "backup_workload",
        status,
        "Configured backup deployment readiness is not backup-success evidence",
        {"ready_replicas": ready, "desired_replicas": desired},
    )


def check_named_workload_metadata(
    args: argparse.Namespace, resource_type: str, name: str, runner: Runner
) -> Check:
    resource, error = get_json(
        args, ["-n", args.backup_namespace, "get", resource_type, name], runner
    )
    check_name = f"backup_{resource_type}:{name}"
    if resource is None:
        return Check(
            check_name,
            "FAIL",
            "Configured workload metadata cannot be read",
            {"error_class": error},
        )
    observed_name, has_name = nested(resource, "metadata.name")
    created, has_created = nested(resource, "metadata.creationTimestamp")
    if (
        not has_name
        or not has_created
        or not isinstance(observed_name, str)
        or not isinstance(created, str)
    ):
        return Check(
            check_name, "FAIL", "Configured workload metadata payload is malformed", {}
        )
    return Check(
        check_name,
        "PASS",
        "Workload metadata exists; it is not artifact or restore evidence",
        {"created_at": created},
    )


def check_backup_record_metadata(args: argparse.Namespace) -> Check:
    if not args.backend_metadata_resource:
        return Check(
            "backup_record_metadata",
            "UNKNOWN",
            "No external backend metadata adapter is configured",
            {},
        )
    return Check(
        "backup_record_metadata",
        "UNKNOWN",
        "External backend metadata is operator-approved but its adapter is disabled; no backend resource was queried",
        {"resource": args.backend_metadata_resource},
    )


def check_restore_evidence() -> Check:
    return Check(
        "restore_record_metadata",
        "UNKNOWN",
        "No restore metadata resource was configured; no operator is assumed",
        {},
    )


def check_restore_verified() -> Check:
    return Check(
        "restore_verified",
        "UNKNOWN",
        "This read-only inventory cannot verify an isolated restore drill",
        {},
    )


def run_preflight(
    args: argparse.Namespace, runner: Runner = readonly_runner
) -> list[Check]:
    args._deadline = time.monotonic() + args.preflight_deadline_seconds
    checks = [check_context(args, runner)]
    checks.extend(
        check_namespace(args, namespace, runner) for namespace in args.namespace
    )
    workload_checks = []
    if args.backup_deployment:
        workload_checks.append(check_backup_workload(args, runner))
    for name in args.backup_cronjob or []:
        workload_checks.append(
            check_named_workload_metadata(args, "cronjob", name, runner)
        )
    for name in args.backup_job or []:
        workload_checks.append(check_named_workload_metadata(args, "job", name, runner))
    if not workload_checks:
        workload_checks.append(
            Check(
                "backup_workload_metadata",
                "UNKNOWN",
                "No backup deployment, Job, or CronJob was configured",
                {},
            )
        )
    checks.extend(
        (
            *workload_checks,
            check_backup_record_metadata(args),
            check_restore_evidence(),
            check_restore_verified(),
        )
    )
    return checks


def emit(checks: Sequence[Check], json_output: bool) -> None:
    summary = {
        status: sum(check.status == status for check in checks)
        for status in ("PASS", "FAIL", "UNKNOWN")
    }
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "summary": summary,
        "checks": [asdict(check) for check in checks],
    }
    if json_output:
        print(json.dumps(payload, sort_keys=True))
    else:
        for check in checks:
            print(f"[{check.status}] {check.name}: {check.message}")
        print(" ".join(f"{name}={count}" for name, count in summary.items()))


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    checks = run_preflight(args)
    emit(checks, args.json)
    if any(check.status == "FAIL" for check in checks):
        return 1
    return 2 if any(check.status == "UNKNOWN" for check in checks) else 0


if __name__ == "__main__":
    raise SystemExit(main())
