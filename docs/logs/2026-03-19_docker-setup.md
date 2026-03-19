# 2026-03-19 Docker Setup Log

## CSP Hash Source
- Source file: `web/src/app/[locale]/layout.tsx`
- Inline script SHA256: `sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8=`

## Verification Summary
- Docker image build: success (`docker build -f deploy/Dockerfile -t learn-claude-code:test .`)
- Runtime checks with read-only + tmpfs: success
- GET / without auth: 401
- GET / with auth: 200
- GET /non-existent-route with auth (SPA fallback): 200
- POST / with auth: 405

## File: .dockerignore
```
.git
.github
**/.DS_Store
**/*.log
**/node_modules
**/.next
**/out
**/dist
**/coverage
**/.cache
.env
.env.*
deploy/.env
```

## File: deploy/Dockerfile
```
FROM node:22-alpine AS builder

WORKDIR /repo
COPY . .

WORKDIR /repo/web
RUN npm ci && npm run build

FROM nginx:alpine

RUN apk add --no-cache openssl \
    && rm -f /etc/nginx/conf.d/default.conf \
    && mkdir -p /run/nginx /var/cache/nginx /tmp /usr/share/nginx/html \
    && chown -R nginx:nginx /run/nginx /var/cache/nginx /tmp /usr/share/nginx/html

COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY deploy/start.sh /start.sh
COPY --from=builder /repo/web/out/ /usr/share/nginx/html/

RUN chmod 755 /start.sh

USER nginx

EXPOSE 8080

ENTRYPOINT ["/start.sh"]
```

## File: deploy/nginx.conf
```
worker_processes auto;
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    client_body_temp_path /tmp/client_temp;
    proxy_temp_path /tmp/proxy_temp;
    fastcgi_temp_path /tmp/fastcgi_temp;
    uwsgi_temp_path /tmp/uwsgi_temp;
    scgi_temp_path /tmp/scgi_temp;

    server_tokens off;
    sendfile on;
    keepalive_timeout 65;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        application/javascript
        application/json
        application/xml
        image/svg+xml;

    server {
        listen 8080;
        listen [::]:8080;
        server_name _;

        root /usr/share/nginx/html;
        index index.html;

        auth_basic "Restricted";
        auth_basic_user_file /tmp/.htpasswd;

        add_header Content-Security-Policy "default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; script-src 'self' 'sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8='; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; upgrade-insecure-requests" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Permissions-Policy "interest-cohort=()" always;

        if ($request_method !~ ^(GET|HEAD)$) {
            return 405;
        }

        location / {
            try_files $uri $uri/ /index.html;
        }
    }
}
```

## File: deploy/docker-compose.yml
```
services:
  web:
    build:
      context: ..
      dockerfile: deploy/Dockerfile
    ports:
      - "8314:8080"
    environment:
      BASIC_AUTH_USER: ${BASIC_AUTH_USER:?BASIC_AUTH_USER is required}
      BASIC_AUTH_PASS: ${BASIC_AUTH_PASS:?BASIC_AUTH_PASS is required}
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
      - /var/cache/nginx
      - /run
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
```

## File: deploy/start.sh
```
#!/bin/sh
set -eu

if [ -z "${BASIC_AUTH_USER:-}" ] || [ -z "${BASIC_AUTH_PASS:-}" ]; then
  echo "BASIC_AUTH_USER and BASIC_AUTH_PASS must be set." >&2
  exit 1
fi

case "${BASIC_AUTH_USER}" in
  *:*|*$'\n'*|*$'\r'*)
    echo "BASIC_AUTH_USER contains invalid characters." >&2
    exit 1
    ;;
esac

HASHED_PASS="$(openssl passwd -apr1 "${BASIC_AUTH_PASS}")"
printf '%s:%s\n' "${BASIC_AUTH_USER}" "${HASHED_PASS}" > /tmp/.htpasswd
chmod 600 /tmp/.htpasswd

exec nginx -g "daemon off;"
```

## File: deploy/README.md
```
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
```

