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
