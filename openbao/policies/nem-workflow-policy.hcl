# Policy for nem.Workflow service
path "secret/data/nem/workflow/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/nem/workflow/*" {
  capabilities = ["read", "list"]
}
