# Docker Deployment (Next.js static export + Nginx)

## Prerequisites
- Docker Engine + Docker Compose plugin
- Set Basic auth credentials via environment variables

## Files
- `Dockerfile`: multi-stage build (Node 22 Alpine -> Nginx Alpine)
- `nginx.conf`: static hosting, Basic auth, security headers, gzip, SPA fallback
- `start.sh`: creates runtime `.htpasswd` from env vars and starts nginx
- `docker-compose.yml`: secure runtime settings

## Run
From `deploy/`:

```bash
export BASIC_AUTH_USER='your-user'
export BASIC_AUTH_PASS='your-strong-password'
docker compose up --build -d
```

Open: http://localhost:8314

## Stop
```bash
docker compose down
```

## Notes
- Basic auth credentials are injected at runtime (not baked into image).
- `.htpasswd` is generated in `/tmp/.htpasswd` inside container.
- Container runs as non-root user `nginx`.
