path "secret/data/nem/sentinel/*" {
  capabilities = ["read"]
}

path "secret/data/nem/shared/*" {
  capabilities = ["read"]
}

path "secret/metadata/nem/sentinel/" {
  capabilities = ["list"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "secret/data/tenant-health-signing/producers/nem.mimir" {
  capabilities = ["read"]
}

path "secret/data/tenant-health-signing/producers/nem.agenticgateway" {
  capabilities = ["read"]
}

path "secret/data/tenant-health-signing/producers/nem.comms" {
  capabilities = ["read"]
}
