# Shared token renewal policy — allows services to renew their own AppRole tokens
# Attach alongside service-specific policies (e.g. token_policies="nem-mcp,nem-renewal")
path "auth/token/renew-self" {
  capabilities = ["update"]
}
