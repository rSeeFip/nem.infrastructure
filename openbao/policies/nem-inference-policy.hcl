# Policy for nem.InferenceGateway (LLM API keys)
path "secret/data/nem/inference/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/nem/inference/*" {
  capabilities = ["read", "list"]
}
