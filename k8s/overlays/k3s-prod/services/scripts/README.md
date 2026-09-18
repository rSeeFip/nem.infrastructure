# Read-only recovery preflight

This tool is an evidence inventory, not a backup or restore operator. It performs only explicitly scoped Kubernetes `get` requests and exits `2` if any required evidence is `UNKNOWN`.

## Metadata and RBAC policy

No backend is assumed. An operator may supply one explicit qualified non-core, non-secret metadata resource together with `--approved-metadata-resource`; core resources, `secrets`, aliases, flags, paths, and comma-separated values are rejected. This is configuration validation only: the external backend adapter is disabled and no metadata resource is queried until a supported adapter is implemented. Approval means only that the resource is intended to contain non-secret metadata; it does not certify its contents.

Grant only `get` on nodes, named namespaces, and explicitly named backup Deployment, Job, or CronJob objects. Do not grant `list`, `watch`, `exec`, secret access, or write verbs. The tool never emits command stdout/stderr. Job/CronJob metadata is workload evidence only, not artifact proof.

## Limits

The tool confirms context reachability, optional pinned node identity, and configured workload metadata. It cannot prove artifact integrity, access credentials, fake in-memory restore results, external backend records, or an isolated restore drill. Those remain `UNKNOWN` and fail the release gate.

## Invocation

Set `KUBE_CONTEXT`, `APP_NAMESPACE`, `BACKUP_NAMESPACE`, and `BACKUP_DEPLOYMENT` to approved actual values before running:

```bash
python3 k8s/overlays/k3s-prod/services/scripts/readonly-recovery-preflight.py \
  --context "$KUBE_CONTEXT" \
  --namespace "$APP_NAMESPACE" \
  --backup-namespace "$BACKUP_NAMESPACE" \
  --backup-deployment "$BACKUP_DEPLOYMENT" \
  --json
```

`--expected-node` and `--expected-node-uid` are optional together when the target node identity is approved. The tool applies both a whole-preflight deadline and a per-`kubectl` request timeout. Exit `2` means required evidence is `UNKNOWN`, not that the tool is broken; exit `1` means a failed check.

Run the fixture suite without creating bytecode:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s k8s/overlays/k3s-prod/services/scripts/tests \
  -p test_readonly_recovery_preflight.py -v
```

## E8 first-slice verification record (2026-09-18)

Source checkpoint: `nem.Workflow` master was published and remotely verified at `a4244bea96dd4b0c9f796ffd8d4d394544bf7382`; `nem.Backup` master was published and remotely verified at `37180e6fe284595bc6d4567114b7e02761635833`. Parent verification recorded the Python fixture suite passing 7 tests and 23 focused .NET tests with builds reporting 0 warnings and 0 errors. The script and tests are at `k8s/overlays/k3s-prod/services/scripts/readonly-recovery-preflight.py` and `k8s/overlays/k3s-prod/services/scripts/tests/test_readonly_recovery_preflight.py`; they are source-only, not deployed, and no deployed tests have run. General restores are not implemented: the public API now truthfully returns `501`; metadata remains `UNKNOWN` and this tool exits `2` when required evidence is unknown. The production disk incident remains unresolved: on 2026-09-18 the parent observed 3.6 GiB free (96% used); it was observed, not fixed.
