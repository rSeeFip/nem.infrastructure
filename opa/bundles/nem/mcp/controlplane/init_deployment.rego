package nem.mcp.controlplane.init_deployment

import rego.v1

default allow_export := false
default allow_import := false
default allow_dry_run := false
default allow_deploy := false
default allow_reset := false
default require_approval := false

# Role bands for init deployment operations.
export_roles := {"ConfigManager", "WorkflowAdmin", "DeploymentAdmin", "FederationAdmin"}
import_roles := {"WorkflowAdmin", "DeploymentAdmin", "FederationAdmin"}
dry_run_roles := {"DeploymentAdmin", "FederationAdmin"}
deploy_roles := {"DeploymentAdmin", "FederationAdmin"}
reset_roles := {"FederationAdmin"}

# Exporting init manifests is the broadest operation.
allow_export if {
	some role in input.subject_roles
	role in export_roles
}

# Importing filled manifests is more restricted than export.
allow_import if {
	some role in input.subject_roles
	role in import_roles
}

# Dry-run validation is restricted to elevated deployment roles.
allow_dry_run if {
	some role in input.subject_roles
	role in dry_run_roles
}

# Actual deployment requires elevated role and approval.
allow_deploy if {
	some role in input.subject_roles
	role in deploy_roles
	input.approval_state == "approved"
}

# Reset + re-initialize is the highest-privilege operation.
allow_reset if {
	some role in input.subject_roles
	role in reset_roles
	input.approval_state == "approved"
	input.reset_confirmed == true
}

# Approval workflow is required for the risky mutating operations.
require_approval if {
	input.operation == "deploy"
}

require_approval if {
	input.operation == "reset"
}

deny_reasons contains reason if {
	not allow_export
	input.operation == "export"
	reason := sprintf("Subject lacks export permission. Required roles: %v, subject roles: %v", [export_roles, input.subject_roles])
}

deny_reasons contains reason if {
	not allow_import
	input.operation == "import"
	reason := sprintf("Subject lacks import permission. Required roles: %v, subject roles: %v", [import_roles, input.subject_roles])
}

deny_reasons contains reason if {
	not allow_dry_run
	input.operation == "dry_run"
	reason := sprintf("Subject lacks dry-run permission. Required roles: %v, subject roles: %v", [dry_run_roles, input.subject_roles])
}

deny_reasons contains reason if {
	not allow_deploy
	input.operation == "deploy"
	reason := sprintf("Subject lacks deploy permission or approval. Required roles: %v, approval: approved, subject roles: %v", [deploy_roles, input.subject_roles])
}

deny_reasons contains reason if {
	not allow_reset
	input.operation == "reset"
	reason := sprintf("Subject lacks reset permission or reset confirmation. Required roles: %v, approval: approved, reset_confirmed: true, subject roles: %v", [reset_roles, input.subject_roles])
}
