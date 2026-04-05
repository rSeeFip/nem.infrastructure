# Policy for nem.Comms service
path "secret/data/nem/comms/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/nem/comms/*" {
  capabilities = ["read", "list"]
}
