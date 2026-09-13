package nem.mcp.controlplane.workflow_execute_test

import rego.v1
import data.nem.mcp.controlplane.workflow_execute

valid_input(roles) := {
    "subject_tenant_id": "22222222-2222-2222-2222-222222222222",
    "resource_tenant_id": "22222222-2222-2222-2222-222222222222",
    "subject_roles": roles,
}

test_allows_workflow_executor_for_matching_tenant if {
    workflow_execute.allow with input as valid_input(["WorkflowExecutor"])
}

test_allows_federation_admin_for_matching_tenant if {
    workflow_execute.allow with input as valid_input(["FederationAdmin"])
}

test_denies_missing_tenant_context if {
    not workflow_execute.allow with input as object.remove(valid_input(["WorkflowExecutor"]), ["subject_tenant_id"])
    not workflow_execute.allow with input as object.remove(valid_input(["WorkflowExecutor"]), ["resource_tenant_id"])
}

test_denies_cross_tenant_execution if {
    not workflow_execute.allow with input as object.union(valid_input(["WorkflowAdmin"]), {"resource_tenant_id": "33333333-3333-3333-3333-333333333333"})
}

test_denies_unprivileged_roles if {
    not workflow_execute.allow with input as valid_input([])
    not workflow_execute.allow with input as valid_input(["WorkflowViewer"])
}
