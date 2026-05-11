#!/bin/bash
# ec2-deploy.sh — ejecutar EN LA EC2 desde la raíz del fork clonado.
#
# Asume que ec2-bootstrap.sh ya corrió (docker instalado, /srv/onlyoffice existe).
#
# Pasos:
#   1. Clona los repos OnlyOffice si no existen
#   2. Aplica el parche al constants.js
#   3. Build de la imagen onlyoffice-fork:local
#   4. Genera .env.prod con JWT_SECRET aleatorio (si no existe)
#   5. Levanta el stack con docker-compose.prod.yml
#   6. Espera healthy

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TAG="v9.3.1.11"
REPOS="core web-apps sdkjs dictionaries core-fonts document-templates build_tools Docker-DocumentServer"

# --- 1. Clonar repos si faltan ---
echo "==> Verificando repos OnlyOffice..."
git config --global core.autocrlf input 2>/dev/null || true
for r in $REPOS; do
    if [ ! -d "$ROOT/$r/.git" ]; then
        echo "  Cloning $r..."
        git clone --depth 1 --branch "$TAG" "https://github.com/ONLYOFFICE/$r.git" "$ROOT/$r" &
    else
        echo "  $r ya existe (skip)"
    fi
done
wait
echo "Clones OK."

# --- 2. Verificar parche en server/Common/sources/constants.js ---
echo "==> Verificando parche..."
if grep -qE '^exports\.LICENSE_CONNECTIONS\s*=\s*100;' server/Common/sources/constants.js; then
    echo "  Parche ya aplicado (LICENSE_CONNECTIONS=100)"
else
    echo "  ERROR: parche no aplicado. Asegúrate de que clonaste TU fork (no upstream)."
    echo "         Espero ver 'exports.LICENSE_CONNECTIONS = 100;' en server/Common/sources/constants.js"
    exit 1
fi

# --- 3. Build de la imagen ---
echo "==> Build de onlyoffice-fork:local (puede tardar 10-20 min la primera vez)..."
docker buildx build --load -f docker/Dockerfile.full -t onlyoffice-fork:local .

# --- 4. .env.prod ---
ENV_FILE="docker/.env.prod"
if [ ! -f "$ENV_FILE" ]; then
    echo "==> Generando $ENV_FILE con JWT_SECRET aleatorio..."
    JWT_SECRET=$(openssl rand -hex 48)
    echo "JWT_SECRET=$JWT_SECRET" > "$ENV_FILE"
    chmod 600 "$ENV_FILE"
fi

# --- 5. Up stack ---
echo "==> Levantando stack..."
docker compose -f docker/docker-compose.prod.yml --env-file "$ENV_FILE" up -d

# --- 6. Esperar healthy ---
echo "==> Esperando healthy..."
for i in $(seq 1 60); do
    STATUS=$(docker inspect --format '{{.State.Health.Status}}' onlyoffice-ds 2>/dev/null || echo "starting")
    if [ "$STATUS" = "healthy" ]; then
        echo "  HEALTHY tras ${i}0s"
        break
    fi
    sleep 5
done

if [ "$STATUS" != "healthy" ]; then
    echo "ERROR: stack no llegó a healthy. Logs:"
    docker logs --tail 50 onlyoffice-ds
    exit 1
fi

# Arrancar example service (demo built-in)
docker exec onlyoffice-ds supervisorctl start ds:example >/dev/null 2>&1 || true

echo ""
echo "================================================================"
echo "Stack desplegado. Comprobar:"
echo "  curl -fsS http://127.0.0.1:8080/healthcheck  → 'true'"
echo ""
echo "Aún falta el Nginx host con SSL. Pasos:"
echo "  sudo cp docker/nginx-host.conf /etc/nginx/sites-available/onlyoffice"
echo "  sudo ln -sf /etc/nginx/sites-available/onlyoffice /etc/nginx/sites-enabled/"
echo "  sudo rm -f /etc/nginx/sites-enabled/default"
echo "  sudo certbot --nginx -d docs.embitech.es --non-interactive --agree-tos -m TU_EMAIL@embitech.es"
echo "  sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo "Tras eso, probar:"
echo "  curl -fsS https://docs.embitech.es/healthcheck  → 'true'"
echo "================================================================"
