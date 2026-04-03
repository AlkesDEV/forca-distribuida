#!/bin/bash
set -e

echo "[entrypoint] Waiting for Redis at $REDIS_URL ..."
until nc -z redis 6379; do
  echo "[entrypoint] Redis not ready, retrying in 2s..."
  sleep 2
done
echo "[entrypoint] Redis is up."

rm -f tmp/pids/server.pid

exec "$@"
