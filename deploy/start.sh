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
