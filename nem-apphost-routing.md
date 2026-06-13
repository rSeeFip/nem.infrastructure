# nem.apphost Routing (WSL + Docker)

This stack now supports host-based routing through `nem-gateway` on port `8090`.

## Hostnames

- `nem.apphost` / `web.nem.apphost` → shell frontend (`nem-web:3000`)
- `cognitive.nem.apphost` → cognitive frontend (`nem-web:3001`)
- `knowhub.nem.apphost` → knowhub frontend (`nem-web:3002`)
- `mcp.nem.apphost` → mcp frontend (`nem-web:3003`)
- `assetcore.nem.apphost` → assetcore frontend (`nem-web:3004`)
- `mimir.nem.apphost` → mimir frontend (`nem-web:3005`)
- `world.nem.apphost` / `holisticworld.nem.apphost` → world frontend (`nem-web:3006`)
- `mediahub.nem.apphost` → mediahub frontend (`nem-web:3007`)
- `home.nem.apphost` / `homeassistant.nem.apphost` → home frontend (`nem-web:3008`)
- `scheduler.nem.apphost` → scheduler frontend (`nem-web:3009`)

### Root-path behavior

For app-specific hosts, `/` is rewritten by gateway to each app base path:

- `cognitive.nem.apphost/` → `/cognitive`
- `knowhub.nem.apphost/` → `/knowhub`
- `mcp.nem.apphost/` → `/mcp`
- `assetcore.nem.apphost/` → `/assetcore`
- `mimir.nem.apphost/` → `/mimir`
- `world.nem.apphost/` / `holisticworld.nem.apphost/` → `/world`
- `mediahub.nem.apphost/` → `/media`
- `home.nem.apphost/` / `homeassistant.nem.apphost/` → `/home`
- `scheduler.nem.apphost/` → `/scheduler`

## Windows hosts entries

Add these entries in `C:\Windows\System32\drivers\etc\hosts`:

```text
127.0.0.1 nem.apphost
127.0.0.1 web.nem.apphost
127.0.0.1 cognitive.nem.apphost
127.0.0.1 knowhub.nem.apphost
127.0.0.1 mcp.nem.apphost
127.0.0.1 assetcore.nem.apphost
127.0.0.1 mimir.nem.apphost
127.0.0.1 world.nem.apphost
127.0.0.1 holisticworld.nem.apphost
127.0.0.1 mediahub.nem.apphost
127.0.0.1 home.nem.apphost
127.0.0.1 homeassistant.nem.apphost
127.0.0.1 scheduler.nem.apphost
```

Then browse through gateway port:

- `http://nem.apphost:8090`
- `http://knowhub.nem.apphost:8090`
- etc.
