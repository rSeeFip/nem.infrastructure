# Admin policy - full CRUD on all nem secrets
path "secret/data/nem/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/nem/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/config" {
  capabilities = ["read"]
}
