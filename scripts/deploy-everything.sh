#!/bin/bash
# deploy-everything.sh — script monolítico para desplegar el fork en una EC2 fresca.
#
# Ejecuta TODO en orden:
#   1. apt update + paquetes base + docker + nginx + certbot + ufw
#   2. crear /srv/onlyoffice/*
#   3. build de la imagen (oficial + branding)
#   4. generar .env.prod con JWT_SECRET
#   5. levantar stack
#   6. configurar Nginx + emitir cert Let's Encrypt
#   7. verificar end-to-end
#
# Uso (en la EC2, desde la raíz del fork descomprimido):
#   sudo bash scripts/deploy-everything.sh editor.embitech.cloud admin@embitech.es
#
# Argumentos:
#   $1 = dominio (default: editor.embitech.cloud)
#   $2 = email para Let's Encrypt (default: admin@embitech.es)

set -euo pipefail

DOMAIN="${1:-editor.embitech.cloud}"
EMAIL="${2:-admin@embitech.es}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USER_NAME="${SUDO_USER:-$USER}"

echo "========================================================"
echo "  Deploy fork OnlyOffice → $DOMAIN"
echo "  Email Let's Encrypt: $EMAIL"
echo "  Root: $ROOT"
echo "  Usuario host: $USER_NAME"
echo "========================================================"

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: ejecuta con sudo:  sudo bash scripts/deploy-everything.sh $DOMAIN $EMAIL"
    exit 1
fi

# =============================================================================
# 1. Paquetes base + Docker
# =============================================================================
echo ""
echo "==> [1/7] Instalando paquetes base..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -yq

apt-get install -yq \
    ca-certificates curl gnupg lsb-release git nginx certbot python3-certbot-nginx ufw

echo "==> [2/7] Instalando Docker Engine..."
if ! command -v docker >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    OS_ID=$(. /etc/os-release && echo "$ID")
    OS_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
    curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/${OS_ID} ${OS_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker "$USER_NAME" || true
else
    echo "  Docker ya instalado: $(docker --version)"
fi

# =============================================================================
# 2. Directorios persistentes + firewall
# =============================================================================
echo ""
echo "==> [3/7] Creando /srv/onlyoffice/* y configurando ufw..."
mkdir -p /srv/onlyoffice/{data,log,lib,db}
chown -R 101:101 /srv/onlyoffice

ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null
ufw --force enable >/dev/null

# =============================================================================
# 3. Build imagen
# =============================================================================
echo ""
echo "==> [4/7] Build de onlyoffice-fork:local (imagen oficial + branding)..."
cd "$ROOT"
docker buildx build --load -f docker/Dockerfile.full -t onlyoffice-fork:local .

# =============================================================================
# 4. .env.prod + up stack
# =============================================================================
ENV_FILE="$ROOT/docker/.env.prod"
if [ ! -f "$ENV_FILE" ]; then
    echo ""
    echo "==> [5a/7] Generando .env.prod..."
    # Si JWT_SECRET viene en el entorno (ej. lo pasaste como `JWT_SECRET=... bash deploy-everything.sh ...`),
    # se respeta. Si no, se genera uno aleatorio.
    if [ -z "${JWT_SECRET:-}" ]; then
        JWT_SECRET=$(openssl rand -hex 48)
        echo "    JWT_SECRET aleatorio generado."
    else
        echo "    JWT_SECRET tomado del entorno (CRM ya lo conoce)."
    fi
    echo "JWT_SECRET=$JWT_SECRET" > "$ENV_FILE"
    chmod 600 "$ENV_FILE"
fi

echo ""
echo "==> [5b/7] Levantando stack..."
docker compose -f "$ROOT/docker/docker-compose.prod.yml" --env-file "$ENV_FILE" up -d

# Esperar healthy
echo "    Esperando healthy..."
STATUS=""
for i in $(seq 1 60); do
    STATUS=$(docker inspect --format '{{.State.Health.Status}}' onlyoffice-ds 2>/dev/null || echo "starting")
    [ "$STATUS" = "healthy" ] && break
    sleep 5
done
if [ "$STATUS" != "healthy" ]; then
    echo "ERROR: stack no llegó a healthy. Logs:"
    docker logs --tail 50 onlyoffice-ds
    exit 1
fi
echo "    Healthy"

# =============================================================================
# 5. Nginx + SSL
# =============================================================================
echo ""
echo "==> [6/7] Configurando Nginx + Let's Encrypt para $DOMAIN..."

# Comprobar DNS
PUB_IP=$(curl -fsS https://checkip.amazonaws.com || echo "?")
DNS_IP=$(getent hosts "$DOMAIN" | awk '{print $1}' | head -1 || echo "?")
if [ "$DNS_IP" != "$PUB_IP" ]; then
    echo "    WARNING: $DOMAIN resuelve a $DNS_IP, esta EC2 es $PUB_IP."
    echo "    Espera a que el DNS propague antes de continuar, o pulsa Ctrl+C."
    sleep 15
fi

mkdir -p /var/www/certbot

# Config Nginx mínima HTTP para ACME challenge (antes del cert)
cat > /etc/nginx/sites-available/onlyoffice <<NGINX_HTTP
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://\$host\$request_uri; }
}
NGINX_HTTP
ln -sf /etc/nginx/sites-available/onlyoffice /etc/nginx/sites-enabled/onlyoffice
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# Emitir cert
certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" \
    --non-interactive --agree-tos -m "$EMAIL" --no-eff-email

# Aplicar config completa (HTTPS + proxy)
sed "s/docs\.embitech\.es/$DOMAIN/g" "$ROOT/docker/nginx-host.conf" \
    > /etc/nginx/sites-available/onlyoffice
nginx -t && systemctl reload nginx

# =============================================================================
# 6. Verificación
# =============================================================================
echo ""
echo "==> [7/7] Verificación end-to-end..."
sleep 3
if curl -fsS "https://$DOMAIN/healthcheck" | grep -q "true"; then
    echo "    https://$DOMAIN/healthcheck → true ✓"
else
    echo "    WARNING: https://$DOMAIN/healthcheck no devolvió 'true'."
    echo "    Comprueba: curl -v https://$DOMAIN/healthcheck"
fi

echo ""
echo "========================================================"
echo "  DEPLOY COMPLETADO"
echo ""
echo "  Editor:     https://$DOMAIN/"
echo "  Healthcheck: https://$DOMAIN/healthcheck"
echo "  Logs:       docker logs -f onlyoffice-ds"
echo "  JWT_SECRET: cat $ENV_FILE  (¡guárdalo!)"
echo "========================================================"
