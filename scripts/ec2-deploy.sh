#!/bin/bash
# ec2-deploy.sh — ejecutar EN LA EC2 desde la raíz del fork clonado:
#   sudo ./scripts/ec2-deploy.sh
#
# Actualiza el editor a la imagen de docker/Dockerfile.full sin perder ediciones:
#   1. Genera docker/.env.prod con JWT_SECRET aleatorio (solo si no existe)
#   2. Guarda la imagen en marcha como onlyoffice-fork:anterior
#   3. Build de onlyoffice-fork:local (imagen oficial + branding)
#   4. Si el editor está en marcha: documentserver-prepare4shutdown.sh, que
#      guarda los documentos abiertos (callbacks al CRM) antes de pararlo
#   5. Levanta el stack con la imagen nueva y espera healthy
#
# Volver a la versión anterior:
#   docker tag onlyoffice-fork:anterior onlyoffice-fork:local
#   docker compose -f docker/docker-compose.prod.yml --env-file docker/.env.prod up -d

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="docker/.env.prod"
COMPOSE=(docker compose -f docker/docker-compose.prod.yml --env-file "$ENV_FILE")

# --- 1. .env.prod ---
if [ ! -f "$ENV_FILE" ]; then
    echo "==> Generando $ENV_FILE con JWT_SECRET aleatorio..."
    JWT_SECRET=$(openssl rand -hex 48)
    echo "JWT_SECRET=$JWT_SECRET" > "$ENV_FILE"
    chmod 600 "$ENV_FILE"
fi

# --- 2. Imagen actual para volver atrás ---
if docker image inspect onlyoffice-fork:local >/dev/null 2>&1; then
    docker tag onlyoffice-fork:local onlyoffice-fork:anterior
    echo "==> Imagen actual guardada como onlyoffice-fork:anterior"
fi

# --- 3. Build de la imagen ---
echo "==> Build de onlyoffice-fork:local..."
docker buildx build --load -f docker/Dockerfile.full -t onlyoffice-fork:local .

# --- 4. Guardar los documentos abiertos ---
if [ "$(docker inspect -f '{{.State.Running}}' onlyoffice-ds 2>/dev/null || echo false)" = "true" ]; then
    echo "==> Guardando documentos abiertos (prepare4shutdown)..."
    docker exec onlyoffice-ds documentserver-prepare4shutdown.sh
fi

# --- 5. Up stack ---
echo "==> Levantando stack..."
"${COMPOSE[@]}" up -d

echo "==> Esperando healthy..."
STATUS="starting"
for i in $(seq 1 60); do
    STATUS=$(docker inspect --format '{{.State.Health.Status}}' onlyoffice-ds 2>/dev/null || echo "starting")
    if [ "$STATUS" = "healthy" ]; then
        echo "  HEALTHY tras $((i * 5))s"
        break
    fi
    sleep 5
done

if [ "$STATUS" != "healthy" ]; then
    echo "ERROR: el editor no llegó a healthy. Logs:"
    docker logs --tail 50 onlyoffice-ds
    echo "Para volver atrás: docker tag onlyoffice-fork:anterior onlyoffice-fork:local && ${COMPOSE[*]} up -d"
    exit 1
fi

echo ""
echo "================================================================"
echo "Editor actualizado. Comprobar:"
echo "  curl -fsS http://127.0.0.1:8080/healthcheck  → 'true'"
echo "  abrir un documento en el CRM, editar, guardar y cerrar"
echo "================================================================"
