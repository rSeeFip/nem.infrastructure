import subprocess
import unittest
from pathlib import Path

import yaml


SERVICES = Path(__file__).parents[2]
OVERLAY = SERVICES / "mimir"
POLICY = OVERLAY / "openbao-recovery-egress-policy.yaml"
KUSTOMIZATION = OVERLAY / "kustomization.yaml"

EXPECTED_POLICY = {
    "apiVersion": "cilium.io/v2",
    "kind": "CiliumNetworkPolicy",
    "metadata": {
        "name": "nem-mimir-openbao-recovery-egress",
        "namespace": "nem-apps",
    },
    "spec": {
        "description": "Allow Mimir to reach the OpenBao recovery endpoint.",
        "endpointSelector": {"matchLabels": {"app": "nem-mimir"}},
        "egress": [
            {
                "toEndpoints": [
                    {
                        "matchLabels": {
                            "io.kubernetes.pod.namespace": "platform-security",
                            "app.kubernetes.io/name": "openbao-recovery",
                        }
                    }
                ],
                "toPorts": [{"ports": [{"port": "8202", "protocol": "TCP"}]}],
            }
        ],
    },
}


class MimirOpenBaoRecoveryEgressPolicyTests(unittest.TestCase):
    def test_policy_has_exactly_the_recovery_permission(self):
        with POLICY.open() as policy_file:
            policy = yaml.safe_load(policy_file)

        self.assertEqual(EXPECTED_POLICY, policy)
        self.assertNotIn("ingress", policy["spec"])
        self.assertNotIn("toCIDR", policy["spec"]["egress"][0])
        self.assertNotIn("toEntities", policy["spec"]["egress"][0])
        self.assertNotIn("toFQDNs", policy["spec"]["egress"][0])

    def test_kustomization_preserves_existing_resources_and_adds_policy(self):
        with KUSTOMIZATION.open() as kustomization_file:
            kustomization = yaml.safe_load(kustomization_file)

        self.assertEqual(
            [
                "configuration-external-secret.yaml",
                "configuration-token-egress-policy.yaml",
                "configuration-service-egress-policy.yaml",
                "openbao-recovery-egress-policy.yaml",
            ],
            kustomization["resources"],
        )

    def test_kustomize_render_includes_recovery_policy_and_existing_resources(self):
        result = subprocess.run(
            ["kubectl", "kustomize", str(OVERLAY)],
            capture_output=True,
            check=True,
            text=True,
        )
        rendered = list(yaml.safe_load_all(result.stdout))
        rendered_resources = {
            (resource["kind"], resource["metadata"]["name"]): resource
            for resource in rendered
        }

        self.assertEqual(
            EXPECTED_POLICY,
            rendered_resources[
                ("CiliumNetworkPolicy", "nem-mimir-openbao-recovery-egress")
            ],
        )
        self.assertIn(
            ("CiliumNetworkPolicy", "nem-mimir-configuration-token-egress"),
            rendered_resources,
        )
        self.assertIn(
            ("CiliumNetworkPolicy", "nem-mimir-configuration-service-egress"),
            rendered_resources,
        )
        self.assertIn(
            ("ExternalSecret", "nem-mimir-configuration-secret"),
            rendered_resources,
        )


if __name__ == "__main__":
    unittest.main()
