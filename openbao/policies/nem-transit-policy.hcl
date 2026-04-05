# Transit encryption policy for PII handling
path "transit/encrypt/nem-*" {
  capabilities = ["update"]
}
path "transit/decrypt/nem-*" {
  capabilities = ["update"]
}
path "transit/keys/nem-*" {
  capabilities = ["read"]
}
