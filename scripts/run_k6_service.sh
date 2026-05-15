#!/bin/sh
set -eu

if [ "$#" -lt 3 ]; then
  echo "Uso: $0 <service> <public-url> <k6-args...>" >&2
  exit 2
fi

SERVICE="$1"
PUBLIC_URL="$2"
shift 2

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
COMPOSE="docker compose --project-directory $ROOT_DIR"
INTERNAL_PORT="${INTERNAL_PORT:-8000}"
READY_PATH="${READY_PATH:-/api/items}"

echo "Aguardando $SERVICE em $PUBLIC_URL$READY_PATH..."
for attempt in $(seq 1 60); do
  if curl -fsS "$PUBLIC_URL$READY_PATH" >/dev/null 2>&1; then
    break
  fi

  if [ "$attempt" -eq 60 ]; then
    echo "Erro: $SERVICE nao respondeu em $PUBLIC_URL$READY_PATH apos 60s." >&2
    exit 1
  fi

  sleep 1
done

CONTAINER_ID=$($COMPOSE ps -q "$SERVICE")
if [ -z "$CONTAINER_ID" ]; then
  echo "Erro: container do servico $SERVICE nao encontrado." >&2
  exit 1
fi

SERVICE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_ID")
if [ -z "$SERVICE_IP" ]; then
  echo "Erro: nao foi possivel obter o IP Docker de $SERVICE." >&2
  exit 1
fi

TARGET_URL="http://$SERVICE_IP:$INTERNAL_PORT"
echo "Executando k6 contra $TARGET_URL"

exec $COMPOSE run --rm k6 run \
  --env TARGET_URL="$TARGET_URL" \
  "$@"
