# Policy for nem.KnowHub service
path "secret/data/nem/knowhub/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/nem/knowhub/*" {
  capabilities = ["read", "list"]
}
