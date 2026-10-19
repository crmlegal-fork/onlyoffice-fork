#!/bin/bash
# apply-nginx-host.sh — ejecutar EN LA EC2 desde la raíz del fork clonado:
#   sudo ./scripts/apply-nginx-host.sh
#
# Instala docker/nginx-host.conf como el sitio de editor.embitech.cloud.
#   1. Comprueba que el contenedor responde y que existe el certificado.
#   2. Copia /etc/nginx entero a /root/nginx-backup-<fecha>.
#   3. Desactiva cualquier otro sitio que sirva el mismo dominio.
#   4. Instala la configuración, valida (nginx -t), recarga y prueba por HTTPS.
# Si cualquier paso falla, restaura la copia y recarga: nginx queda como estaba.

set -euo pipefail

DOMAIN=editor.embitech.cloud
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/docker/nginx-host.conf"
DEST=/etc/nginx/sites-available/onlyoffice
LINK=/etc/nginx/sites-enabled/onlyoffice
BACKUP="/root/nginx-backup-$(date +%Y%m%d-%H%M%S)"

[ "$(id -u)" -eq 0 ] || { echo "Ejecutar con sudo"; exit 1; }
[ -f "$SRC" ] || { echo "No existe $SRC"; exit 1; }
curl -sf --max-time 5 http://127.0.0.1:8080/healthcheck >/dev/null \
	|| { echo "El contenedor no responde en 127.0.0.1:8080: no se toca nginx"; exit 1; }
[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] \
	|| { echo "Falta el certificado en /etc/letsencrypt/live/$DOMAIN"; exit 1; }

cp -a /etc/nginx "$BACKUP"
echo "==> Copia de seguridad: $BACKUP"

restore() {
	echo "==> FALLO: restaurando $BACKUP"
	rm -rf /etc/nginx
	cp -a "$BACKUP" /etc/nginx
	nginx -t && systemctl reload nginx
	exit 1
}
trap restore ERR

echo "==> Sitios que sirven $DOMAIN ahora mismo:"
for f in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
	[ -e "$f" ] || continue
	grep -qE "server_name[^;]*\b$DOMAIN\b" "$f" || continue
	if [ "$(readlink -f "$f")" = "$DEST" ]; then
		echo "    $f (se sustituye)"
	else
		echo "    $f (se desactiva)"
		rm -f "$f"
	fi
done

install -m 644 "$SRC" "$DEST"
ln -sf "$DEST" "$LINK"

echo "==> nginx -t"
nginx -t
systemctl reload nginx
sleep 2

echo "==> Comprobaciones por HTTPS"
curl -sf --max-time 10 --resolve "$DOMAIN:443:127.0.0.1" \
	"https://$DOMAIN/healthcheck" >/dev/null
curl -sI --max-time 10 --resolve "$DOMAIN:443:127.0.0.1" \
	"https://$DOMAIN/web-apps/apps/api/documents/api.js" \
	| grep -qi "frame-ancestors 'self' https://app.embitech.cloud"

trap - ERR
echo "==> OK. Copia anterior en $BACKUP (borrarla cuando el editor funcione en el CRM)."
