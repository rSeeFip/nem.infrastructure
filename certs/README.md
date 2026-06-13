# mTLS Certificate Management — DEV ONLY

> **WARNING**: These certificates are for local development only.
> Never use dev certificates in production. Use a proper PKI (e.g., HashiCorp Vault PKI, Let's Encrypt, or your org's CA).

## Quick Start

```bash
# 1. Generate all certificates
cd nem.infrastructure/certs
./generate-dev-certs.sh

# 2. Start infrastructure with TLS
cd nem.infrastructure
docker compose -f docker-compose.yml -f docker-compose.tls.yml up -d

# 3. (Optional) Start .NET services with TLS config
DOTNET_ENVIRONMENT=Tls dotnet run --project nem.AppHost
```

## Certificate Hierarchy

```
Root CA (4096-bit RSA, 10 years)
└── Intermediate CA (4096-bit RSA, 5 years)
    ├── Server Certificates (2048-bit RSA, 1 year)
    │   ├── postgres       (DNS: postgres, nem-postgres, localhost)
    │   ├── rabbitmq       (DNS: rabbitmq, nem-rabbitmq, localhost)
    │   ├── keycloak       (DNS: keycloak, nem-keycloak, localhost)
    │   ├── gateway        (DNS: gateway, nem-gateway, localhost)
    │   ├── mcp            (DNS: mcp, nem-mcp, localhost)
    │   ├── knowhub        (DNS: knowhub, nem-knowhub, localhost)
    │   ├── holisticworld  (DNS: holisticworld, nem-holisticworld, localhost)
    │   ├── assetcore      (DNS: assetcore, nem-assetcore, localhost)
    │   ├── mediahub       (DNS: mediahub, nem-mediahub, localhost)
    │   ├── mimir          (DNS: mimir, nem-mimir, localhost)
    │   ├── scheduler      (DNS: scheduler, nem-scheduler, localhost)
    │   ├── workflow       (DNS: workflow, nem-workflow, localhost)
    │   └── inferencegateway (DNS: inferencegateway, nem-inferencegateway, localhost)
    │
    └── Client Certificates (2048-bit RSA, 1 year)
        ├── mcp-client, knowhub-client, holisticworld-client
        ├── assetcore-client, mediahub-client, mimir-client
        ├── scheduler-client, workflow-client
        ├── inferencegateway-client, gateway-client
        └── (All include client auth EKU for mTLS)
```

## Output Directory Structure

```
output/
├── ca/
│   ├── root-ca.crt          # Root CA certificate
│   └── root-ca.key          # Root CA private key (KEEP SECRET)
├── intermediate/
│   ├── intermediate-ca.crt  # Intermediate CA certificate
│   └── intermediate-ca.key  # Intermediate CA private key (KEEP SECRET)
├── ca-chain.crt             # Full chain: Intermediate + Root (trust anchor)
├── services/<name>/
│   ├── server.crt           # Server certificate
│   ├── server.key           # Server private key
│   └── server.pfx           # PKCS#12 bundle (for .NET, password: dev-only)
└── clients/<name>/
    ├── client.crt            # Client certificate
    ├── client.key            # Client private key
    └── client.pfx            # PKCS#12 bundle (for .NET, password: dev-only)
```

## Certificate Rotation

### When to Rotate

| Certificate | Validity | Rotation Trigger |
|-------------|----------|------------------|
| Root CA | 10 years | Compromise only |
| Intermediate CA | 5 years | Before expiry or compromise |
| Server certs | 1 year | Before expiry, service change, or compromise |
| Client certs | 1 year | Before expiry, service change, or compromise |

### How to Rotate (Dev Environment)

#### Rotate All Certificates (Nuclear Option)

```bash
cd nem.infrastructure/certs
./generate-dev-certs.sh --force

# Restart all services to pick up new certs
cd ..
docker compose -f docker-compose.yml -f docker-compose.tls.yml down
docker compose -f docker-compose.yml -f docker-compose.tls.yml up -d
```

#### Rotate a Single Service

```bash
cd nem.infrastructure/certs
./generate-dev-certs.sh --service postgres

# Restart only that service
cd ..
docker compose -f docker-compose.yml -f docker-compose.tls.yml restart postgres
```

#### Check Certificate Expiry

```bash
# Check a specific certificate
openssl x509 -in output/services/postgres/server.crt -noout -dates

# Check all server certificates
for cert in output/services/*/server.crt; do
  echo "=== $(dirname $cert | xargs basename) ==="
  openssl x509 -in "$cert" -noout -dates
done

# Verify chain
openssl verify -CAfile output/ca-chain.crt output/services/postgres/server.crt
```

### Production Rotation Procedure

In production, use a proper PKI. Recommended approach:

1. **Use OpenBao (Vault) PKI secrets engine** — auto-issues and rotates certs
2. **Configure cert-manager** (Kubernetes) or **ACME** for automatic renewal
3. **Rolling restart** — update certs per service, one at a time:
   - Generate new cert for service X
   - Deploy new cert alongside old (both trusted)
   - Restart service X
   - Verify connectivity
   - Remove old cert from trust store
4. **Monitor expiry** — set Prometheus alerts for certs expiring within 30 days

## Configuration Files

| File | Purpose |
|------|---------|
| `generate-dev-certs.sh` | Certificate generation script |
| `rabbitmq-ssl.conf` | RabbitMQ TLS configuration (AMQPS on 5671, mTLS) |
| `postgres-ssl-init.sh` | PostgreSQL SSL initialization (entrypoint script) |
| `../docker-compose.tls.yml` | Docker Compose TLS overlay |
| `../../nem.AppHost/appsettings.Tls.json` | Aspire TLS configuration |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TLS_CERT_DIR` | `./certs/output` | Path to generated certificate output |
| `TLS_PFX_PASSWORD` | `dev-only` | PFX file password for .NET services |
| `CERT_DAYS` | `365` | Server/client certificate validity (days) |
| `CA_DAYS` | `3650` | Root CA validity (days) |
| `INTERMEDIATE_DAYS` | `1825` | Intermediate CA validity (days) |
| `KEY_SIZE` | `2048` | Server/client key size (bits) |
| `CA_KEY_SIZE` | `4096` | CA key size (bits) |

## Troubleshooting

### "certificate verify failed"
- Ensure `ca-chain.crt` is mounted and referenced correctly
- Check that the cert was signed by the same CA chain: `openssl verify -CAfile output/ca-chain.crt output/services/<name>/server.crt`

### "handshake failure"
- Verify TLS protocol version (1.2+ required)
- Check that server SAN includes the hostname being connected to
- For mTLS: ensure client cert has `clientAuth` extended key usage

### PostgreSQL SSL not working
- Check that `postgres-ssl-init.sh` ran (look in container logs)
- Verify key permissions: `ls -la /var/lib/postgresql/data/server.*` (should be 600)
- Connection string must include `SSL Mode=Verify-CA` or `SSL Mode=Require`

### RabbitMQ AMQPS not working
- Verify port 5671 is exposed and mapped
- Check RabbitMQ logs: `docker logs nem-rabbitmq 2>&1 | grep -i ssl`
- Test connection: `openssl s_client -connect localhost:5671 -CAfile output/ca-chain.crt`

### .NET PFX loading errors
- Verify PFX password matches `TLS_PFX_PASSWORD` env var (default: `dev-only`)
- Ensure PFX file exists: `ls -la output/services/<name>/server.pfx`
- Test PFX: `openssl pkcs12 -in output/services/<name>/server.pfx -nokeys -passin pass:dev-only`
