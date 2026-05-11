# Despliegue en EC2

Guía paso a paso para subir el fork de OnlyOffice a tu EC2 con dominio `docs.embitech.es` + SSL.

## Estado de partida (asumido)

- EC2 corriendo, accesible por SSH.
- Tu local: este repo con `server/` parcheado + branding aplicado.
- Tu DNS: control sobre el dominio `embitech.es` para crear un A record.
- Cert SSL: lo emite **Let's Encrypt** automáticamente con `certbot` durante el despliegue (gratis, renovación automática).

## Recursos creados

- [docker/docker-compose.prod.yml](docker/docker-compose.prod.yml) — compose para EC2 (bind mounts a `/srv/onlyoffice`, sin `host.docker.internal`).
- [docker/nginx-host.conf](docker/nginx-host.conf) — config Nginx host con TLS termination + WebSocket proxy.
- [scripts/ec2-bootstrap.sh](scripts/ec2-bootstrap.sh) — instala docker, nginx, certbot, ufw en EC2 fresca.
- [scripts/ec2-deploy.sh](scripts/ec2-deploy.sh) — clona repos OnlyOffice, build, up.

---

## Paso 0 — DNS

En tu proveedor de DNS (Route53, Cloudflare, etc.):
```
docs.embitech.es   A   <IP_PUBLICA_EC2>   TTL 300
```
Verifica con: `dig docs.embitech.es +short` (debe devolver tu IP EC2).

## Paso 1 — Hacer llegar el código a la EC2

**Recomendado: vía Git** — crea un repo privado (GitLab/GitHub/Bitbucket) con este proyecto y clónalo en EC2.

Como alternativa rápida sin Git remoto, **archivo + scp**:

```powershell
# En tu Windows local — empaqueta SOLO lo que necesita la EC2
# (server con parche, docker/, scripts/, patches/, DEPLOY.md, README.md)
cd C:\Users\ignasi\Desktop\Onlyoffice
$tmp = "C:\Users\ignasi\Desktop\onlyoffice-fork.tar.gz"
tar --exclude='server/node_modules' --exclude='*/node_modules' -czf $tmp `
    server docker scripts patches examples DEPLOY.md README.md .gitattributes .gitignore .dockerignore

# Subir a EC2 (sustituye ubuntu@TU_IP y la ruta de tu key .pem)
scp -i "C:\path\to\tu-key.pem" $tmp ubuntu@TU_IP:/home/ubuntu/
```

En la EC2:
```bash
mkdir -p ~/onlyoffice-fork && cd ~/onlyoffice-fork
tar -xzf ~/onlyoffice-fork.tar.gz
```

## Paso 2 — Bootstrap de la EC2 (una sola vez)

```bash
# En la EC2, dentro de ~/onlyoffice-fork/
chmod +x scripts/ec2-bootstrap.sh
./scripts/ec2-bootstrap.sh docs.embitech.es
```

Esto instala: docker + buildx + compose, nginx, certbot, ufw, y crea `/srv/onlyoffice/{data,log,lib,db}` con perms correctos.

**Después del bootstrap, cierra sesión SSH y vuelve a entrar** (para que el grupo `docker` haga efecto en tu usuario).

## Paso 3 — Deploy del stack OnlyOffice

```bash
cd ~/onlyoffice-fork
chmod +x scripts/ec2-deploy.sh
./scripts/ec2-deploy.sh
```

Esto:
1. Clona los repos OnlyOffice que faltan (`core`, `web-apps`, `sdkjs`, etc. en `v9.3.1.11`).
2. Build de la imagen `onlyoffice-fork:local` (10-20 min la primera vez).
3. Genera `docker/.env.prod` con `JWT_SECRET` aleatorio.
4. Levanta el contenedor con `docker-compose.prod.yml`.
5. Espera `healthy`.

Verificación manual:
```bash
curl -fsS http://127.0.0.1:8080/healthcheck   # → true
```

## Paso 4 — Nginx + SSL

```bash
# Copiar config Nginx
sudo cp docker/nginx-host.conf /etc/nginx/sites-available/onlyoffice
sudo ln -sf /etc/nginx/sites-available/onlyoffice /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Crear directorio para ACME challenge
sudo mkdir -p /var/www/certbot

# Test config (aún sin cert, dará error en ssl_certificate — normal)
# Edita temporalmente el bloque 443 para comentarlo o usa el comando standalone:

# Emitir cert con Let's Encrypt (modo nginx; certbot inyecta config temporal)
sudo certbot --nginx -d docs.embitech.es \
    --non-interactive --agree-tos \
    -m tu-email@embitech.es

# Restaurar nginx-host.conf y recargar
sudo cp docker/nginx-host.conf /etc/nginx/sites-available/onlyoffice
sudo nginx -t
sudo systemctl reload nginx
```

Verificar:
```bash
curl -fsS https://docs.embitech.es/healthcheck   # → true
curl -I https://docs.embitech.es/web-apps/apps/api/documents/api.js   # → HTTP/2 200
```

## Paso 5 — Actualizar el CRM/stub

En tu CRM (o en el stub `examples/crm-mock/`) cambiar:
```env
PUBLIC_HOST=docs.embitech.es        # antes: host.docker.internal:3000
```
Y los URLs del DocsAPI deben apuntar a:
```js
const DS_BASE = "https://docs.embitech.es";
```

El `callbackUrl` y `document.url` del config deben usar URLs **públicas** y **HTTPS** accesibles desde la EC2.

## Operación

| Acción | Comando |
|---|---|
| Ver estado del stack | `docker compose -f docker/docker-compose.prod.yml ps` |
| Logs del DocumentServer | `docker logs -f onlyoffice-ds` |
| Reiniciar | `docker compose -f docker/docker-compose.prod.yml restart` |
| Actualizar imagen tras patch | `./scripts/ec2-deploy.sh` (rebuild incremental) |
| Backup datos | `sudo tar -czf onlyoffice-backup-$(date +%F).tar.gz /srv/onlyoffice/data /srv/onlyoffice/db` |
| Renovar cert (cron lo hace solo) | `sudo certbot renew --dry-run` |

## Troubleshooting

| Síntoma | Causa probable / fix |
|---|---|
| `curl /healthcheck` falla con 502 | El contenedor no está healthy. `docker logs onlyoffice-ds`. |
| Nginx 502 Bad Gateway | El contenedor escucha en 127.0.0.1:8080. Verifica con `docker ps`. |
| Editor carga pero "Download failed" | El `document.url` del callback no es accesible desde el contenedor. Tiene que ser HTTPS público. |
| Mixed-content warnings | El CRM (HTTPS) embebe assets HTTP. El editor DEBE servirse por HTTPS (paso 4). |
| Cert SSL no renueva | `sudo certbot renew --dry-run` para diagnosticar. |
| `docker buildx build` agota memoria | EC2 muy pequeña. Necesitas ≥4 GB RAM durante build. Considera t3.large o ampliar swap. |

## TODO pendientes (NO bloqueantes)

- [ ] Subir el fork a repo público (compliance AGPL v3).
- [ ] Configurar backups automáticos (cron + S3).
- [ ] Spell-check server-side (opcional, el cliente ya corrige).
- [ ] Rate limiting en Nginx.
- [ ] Monitorización (CloudWatch o similar).
