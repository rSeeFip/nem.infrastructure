package nem.mcp.controlplane.init_deployment_test

import rego.v1

import data.nem.mcp.controlplane.init_deployment

test_export_allowed_for_config_manager if {
	init_deployment.allow_export with input as {
		"operation": "export",
		"subject_roles": ["ConfigManager"],
	}
}

test_import_allowed_for_workflow_admin if {
	init_deployment.allow_import with input as {
		"operation": "import",
		"subject_roles": ["WorkflowAdmin"],
	}
}

test_import_denied_for_config_manager if {
	not init_deployment.allow_import with input as {
		"operation": "import",
		"subject_roles": ["ConfigManager"],
	}
}

test_dry_run_allowed_for_deployment_admin if {
	init_deployment.allow_dry_run with input as {
		"operation": "dry_run",
		"subject_roles": ["DeploymentAdmin"],
	}
}

test_deploy_allowed_with_approval if {
	init_deployment.allow_deploy with input as {
		"operation": "deploy",
		"subject_roles": ["DeploymentAdmin"],
		"approval_state": "approved",
	}
}

test_deploy_denied_without_approval if {
	not init_deployment.allow_deploy with input as {
		"operation": "deploy",
		"subject_roles": ["DeploymentAdmin"],
		"approval_state": "pending",
	}
}

test_reset_allowed_for_federation_admin if {
	init_deployment.allow_reset with input as {
		"operation": "reset",
		"subject_roles": ["FederationAdmin"],
		"approval_state": "approved",
		"reset_confirmed": true,
	}
}

test_reset_denied_for_deployment_admin if {
	not init_deployment.allow_reset with input as {
		"operation": "reset",
		"subject_roles": ["DeploymentAdmin"],
		"approval_state": "approved",
		"reset_confirmed": true,
	}
}

test_require_approval_for_deploy if {
	init_deployment.require_approval with input as {
		"operation": "deploy",
	}
}

test_require_approval_for_reset if {
	init_deployment.require_approval with input as {
		"operation": "reset",
	}
}

test_no_approval_required_for_dry_run if {
	not init_deployment.require_approval with input as {
		"operation": "dry_run",
	}
}
