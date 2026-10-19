# Despliegue en EC2

El editor del CRM vive en `editor.embitech.cloud`.

## Topología

- **EC2** con acceso por AWS Systems Manager (Session Manager, usuario `ssm-user`).
- **Contenedor** `onlyoffice-ds` ([docker/docker-compose.prod.yml](docker/docker-compose.prod.yml)) escuchando solo en `127.0.0.1:8080`. Datos en `${DATA_ROOT:-/home/ssm-user/onlyoffice}/{data,logs,lib,db}`; `JWT_SECRET` en `docker/.env.prod` (no versionado; tiene que coincidir con `ONLYOFFICE_JWT_SECRET` del backend del CRM); `JWT_HEADER=Authorization`, `JWT_IN_BODY=true`.
- **nginx del host** ([docker/nginx-host.conf](docker/nginx-host.conf)): termina TLS en 443, redirige 80 → 443, cabeceras de seguridad, `frame-ancestors` limitado al CRM, `/source` → repo público, `/example` bloqueado, proxy con WebSocket al contenedor.

## Actualizar el editor (caso habitual)

En Session Manager, en una hora sin nadie editando:

```bash
cd <ruta del fork> && git pull && sudo ./scripts/ec2-deploy.sh
```

[scripts/ec2-deploy.sh](scripts/ec2-deploy.sh):
1. Guarda la imagen en marcha como `onlyoffice-fork:anterior`.
2. Compila `onlyoffice-fork:local` (imagen oficial + branding; un par de minutos).
3. Ejecuta `documentserver-prepare4shutdown.sh` (unos 15 s): el editor guarda los documentos abiertos y manda los callbacks al CRM.
4. Levanta el stack con la imagen nueva y espera `healthy`.

Volver atrás:
```bash
docker tag onlyoffice-fork:anterior onlyoffice-fork:local
docker compose -f docker/docker-compose.prod.yml --env-file docker/.env.prod up -d
```

Después: abrir un documento en el CRM, editar, guardar y cerrar; y revisar en S3 que no haya ficheros nuevos en `.../despachos/<id>/onlyoffice/recuperados/` (guardados de sesiones que el CRM aparta para no pisar el documento).

## nginx del host

```bash
sudo ./scripts/apply-nginx-host.sh
```

Copia `/etc/nginx` a `/root/nginx-backup-<fecha>`, desactiva cualquier otro sitio del dominio, instala la configuración, valida con `nginx -t`, recarga y prueba por HTTPS. Si algo falla, restaura la copia sola. nginx 1.24 (Ubuntu 24.04) solo admite `http2` como parámetro de `listen`.

## EC2 nueva desde cero

1. DNS: `editor.embitech.cloud A <IP_PUBLICA_EC2>`.
2. En la EC2, desde la raíz del fork: `sudo bash scripts/deploy-everything.sh editor.embitech.cloud <email>` (paquetes, Docker, nginx, certbot, ufw, build, `.env.prod`, stack, nginx + certificado). Si el CRM ya tiene un `ONLYOFFICE_JWT_SECRET`, pásalo como `JWT_SECRET=... sudo -E bash scripts/deploy-everything.sh ...`.

## Certificado

El certificado actual se emitió con validación DNS manual: `certbot renew` no lo renueva solo y hay que hacerlo a mano antes de que caduque (cada 90 días). Tras renovarlo, `sudo nginx -t && sudo systemctl reload nginx`. Síntoma de certificado caducado: el editor sale en blanco en el CRM. Comprobar la fecha: `openssl s_client -connect editor.embitech.cloud:443 </dev/null | openssl x509 -noout -enddate`.

## Operación

| Acción | Comando |
|---|---|
| Estado del stack | `docker compose -f docker/docker-compose.prod.yml ps` |
| Logs del editor | `docker logs -f onlyoffice-ds` |
| Reiniciar (guarda antes los documentos abiertos) | `docker compose -f docker/docker-compose.prod.yml restart` |
| Actualizar a otra versión | ver README, «Actualizar a otra versión de OnlyOffice» |
| Backup de datos | `sudo tar -czf onlyoffice-backup-$(date +%F).tar.gz /home/ssm-user/onlyoffice/data /home/ssm-user/onlyoffice/db` |

## Troubleshooting

| Síntoma | Causa probable / fix |
|---|---|
| `curl /healthcheck` falla con 502 | El contenedor no está healthy: `docker logs onlyoffice-ds`. |
| Editor en blanco en el CRM | Certificado caducado (ver arriba) o `JWT_SECRET` distinto del `ONLYOFFICE_JWT_SECRET` del CRM. |
| Editor carga pero «Download failed» | El `document.url` que manda el CRM no es accesible desde el contenedor: tiene que ser HTTPS público. |
| El build falla en el branding | Una versión nueva de OnlyOffice movió un fichero o un estilo: el mensaje `BRANDING:` dice cuál; ajustar `docker/branding/apply-branding.sh`. |

## Pendiente

- [ ] Backups automáticos (cron + S3).
- [ ] Rate limiting en nginx.
- [ ] Monitorización (CloudWatch o similar).
