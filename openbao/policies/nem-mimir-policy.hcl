# Policy for nem.Mimir service
path "secret/data/nem/mimir/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/nem/mimir/*" {
  capabilities = ["read", "list"]
}
