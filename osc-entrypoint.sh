#!/bin/bash
set -eo pipefail

PORT=${PORT:-8080}
GHOST_CONTENT=${GHOST_CONTENT:-/var/lib/ghost/content}
GHOST_INSTALL=${GHOST_INSTALL:-/var/lib/ghost}

# Ghost listens on its internal port; we map OSC PORT via server__port config
export server__port="${PORT}"
export server__host="0.0.0.0"

# Map OSC_HOSTNAME to Ghost's url (required for Ghost to function correctly)
if [ -n "$OSC_HOSTNAME" ]; then
    export url="${url:-https://${OSC_HOSTNAME}}"
fi

# If url is still not set, default to localhost
export url="${url:-http://localhost:${PORT}}"

# Parse DATABASE_URL into Ghost database config
if [ -n "$DATABASE_URL" ]; then
    DB_PROTO="${DATABASE_URL%%://*}"
    DB_REST="${DATABASE_URL#*://}"
    DB_USERINFO="${DB_REST%%@*}"
    DB_HOSTPATH="${DB_REST#*@}"
    DB_USER="${DB_USERINFO%%:*}"
    DB_PASS="${DB_USERINFO#*:}"
    DB_HOSTPORT="${DB_HOSTPATH%%/*}"
    DB_NAME="${DB_HOSTPATH#*/}"
    DB_HOST="${DB_HOSTPORT%%:*}"
    DB_PORT="${DB_HOSTPORT#*:}"

    if [ "$DB_PROTO" = "postgres" ] || [ "$DB_PROTO" = "postgresql" ]; then
        if [ "$DB_PORT" = "$DB_HOST" ]; then DB_PORT="5432"; fi
        export database__client="pg"
    elif [ "$DB_PROTO" = "mysql" ] || [ "$DB_PROTO" = "mariadb" ]; then
        if [ "$DB_PORT" = "$DB_HOST" ]; then DB_PORT="3306"; fi
        export database__client="mysql2"
    fi

    export database__connection__host="${DB_HOST}"
    export database__connection__port="${DB_PORT}"
    export database__connection__user="${DB_USER}"
    export database__connection__password="${DB_PASS}"
    export database__connection__database="${DB_NAME}"
elif [ -n "$MYSQL_HOST" ]; then
    export database__client="mysql2"
    export database__connection__host="${MYSQL_HOST}"
    export database__connection__port="${MYSQL_PORT:-3306}"
    export database__connection__user="${MYSQL_USER:-ghost}"
    export database__connection__password="${MYSQL_PASSWORD}"
    export database__connection__database="${MYSQL_DB:-ghost}"
elif [ -n "$POSTGRES_HOST" ]; then
    export database__client="pg"
    export database__connection__host="${POSTGRES_HOST}"
    export database__connection__port="${POSTGRES_PORT:-5432}"
    export database__connection__user="${POSTGRES_USER:-ghost}"
    export database__connection__password="${POSTGRES_PASSWORD}"
    export database__connection__database="${POSTGRES_DB:-ghost}"
fi

# Mail configuration (SMTP)
if [ -n "$SMTP_HOST" ]; then
    export mail__transport="SMTP"
    export mail__options__host="${SMTP_HOST}"
    export mail__options__port="${SMTP_PORT:-587}"
    export mail__options__auth__user="${SMTP_USER}"
    export mail__options__auth__pass="${SMTP_PASS}"
fi

if [ -n "$MAIL_FROM" ]; then
    export mail__from="${MAIL_FROM}"
fi

# Persistent content path
export paths__contentPath="${GHOST_CONTENT}"

# Ensure content dir and subdirs exist
mkdir -p "${GHOST_CONTENT}"

# Bootstrap content directory from Ghost's default content if themes are missing
if [ ! -d "${GHOST_CONTENT}/themes" ]; then
    echo "Bootstrapping Ghost content directory..."
    GHOST_VERSION_DIR="${GHOST_INSTALL}/current/content"
    if [ -d "$GHOST_VERSION_DIR" ]; then
        cp -rn "$GHOST_VERSION_DIR"/* "${GHOST_CONTENT}/" 2>/dev/null || true
    fi
fi

# Ensure required subdirectories exist even if copy was partial
mkdir -p "${GHOST_CONTENT}/themes" "${GHOST_CONTENT}/data" "${GHOST_CONTENT}/logs" "${GHOST_CONTENT}/adapters" "${GHOST_CONTENT}/media" "${GHOST_CONTENT}/images" "${GHOST_CONTENT}/files"

exec "$@"
