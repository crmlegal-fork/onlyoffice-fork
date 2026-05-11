#!/bin/bash
# ec2-bootstrap.sh — instala dependencias en una EC2 fresca.
# Tested en Ubuntu 22.04 / 24.04 / Debian 12.
#
# Uso:
#   ssh ubuntu@<EC2_IP> 'bash -s' < scripts/ec2-bootstrap.sh
# o bien copiar el script a la EC2 y ejecutarlo:
#   scp scripts/ec2-bootstrap.sh ubuntu@<EC2_IP>:/tmp/
#   ssh ubuntu@<EC2_IP> 'bash /tmp/ec2-bootstrap.sh'

set -euo pipefail

DOMAIN="${1:-docs.embitech.es}"

echo "==> Update apt"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq

echo "==> Instalar paquetes base"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq \
    ca-certificates curl gnupg lsb-release git nginx certbot python3-certbot-nginx ufw

echo "==> Instalar Docker Engine (oficial)"
if ! command -v docker >/dev/null 2>&1; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
fi

echo "==> Crear directorios de datos en /srv/onlyoffice"
sudo mkdir -p /srv/onlyoffice/{data,log,lib,db}
sudo chown -R 101:101 /srv/onlyoffice  # uid del usuario ds en el contenedor

echo "==> Firewall (ufw)"
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'   # 80 + 443
sudo ufw --force enable

echo "==> Verificar DNS de $DOMAIN"
if ! getent hosts "$DOMAIN" >/dev/null; then
    echo "WARNING: $DOMAIN no resuelve. Asegúrate de tener un A record apuntando a esta EC2."
    echo "         El paso de certbot fallará hasta que el DNS propague."
else
    PUB_IP=$(curl -fsS https://checkip.amazonaws.com)
    DNS_IP=$(getent hosts "$DOMAIN" | awk '{print $1}' | head -1)
    if [ "$PUB_IP" != "$DNS_IP" ]; then
        echo "WARNING: $DOMAIN resuelve a $DNS_IP pero esta EC2 es $PUB_IP."
    fi
fi

echo ""
echo "================================================================"
echo "Bootstrap completado."
echo ""
echo "Siguientes pasos manuales:"
echo "  1. Clonar el repo del fork en /home/$USER/onlyoffice-fork/"
echo "  2. Ejecutar scripts/ec2-deploy.sh"
echo "  3. Emitir cert SSL con:  sudo certbot --nginx -d $DOMAIN"
echo "  4. Aplicar nginx-host.conf a /etc/nginx/sites-available/onlyoffice"
echo "================================================================"

# Salida limpia para que el usuario pueda re-loguearse con perms de docker
echo ""
echo "NOTA: cierra sesión SSH y vuelve a entrar para que el grupo 'docker' sea efectivo."
