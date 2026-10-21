# Policy for nem.Comms service
# Named channel accounts and Telegram runtime setup read keys stored at this root path.
path "secret/data/nem/comms" {
  capabilities = ["read"]
}

path "secret/data/nem/comms/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/nem/comms/*" {
  capabilities = ["read", "list"]
}

# SMTP account definitions and credentials live together in this dedicated KV-v2 path.
path "secret/data/nem/comms/smtp" {
  capabilities = ["create", "update", "read"]
}

# The workflow bridge verifies its existing HMAC key before becoming ready.
path "secret/data/message-signing/producers/workflow-comms" {
  capabilities = ["read"]
}

# Tenant health reports use a dedicated Comms producer key.
path "secret/data/tenant-health-signing/producers/nem.comms" {
  capabilities = ["read"]
}
