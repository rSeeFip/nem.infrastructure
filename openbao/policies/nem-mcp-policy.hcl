# Policy for nem.MCP service
path "secret/data/nem/mcp/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/nem/mcp/*" {
  capabilities = ["read", "list"]
}
