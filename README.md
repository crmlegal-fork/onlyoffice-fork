# OnlyOffice DocumentServer — fork interno

Fork del [OnlyOffice DocumentServer](https://github.com/ONLYOFFICE/DocumentServer) (AGPL v3) para integración con CRM propio. Editores Word, Excel y PDF servidos desde EC2 vía iframe.

> **Versión modificada de ONLYOFFICE Docs** (Document Server), desarrollado por Ascensio System SIA.
> Modificado por Embitech el 19-10-2026.
>
> **Base**: release `v9.4.0` de ONLYOFFICE Docs, imagen Docker oficial `onlyoffice/documentserver:9.4.0.1`.

## Modificaciones aplicadas

Todas se hacen sobre la imagen oficial en [docker/branding/apply-branding.sh](docker/branding/apply-branding.sh): en el editor cambian solo logos, textos y enlaces, y el servidor no se modifica.

| # | Cambio | Justificación |
|---|---|---|
| 1 | Logo de la cabecera y del diálogo Acerca de → Embitech | Integración visual en el CRM. Los textos de autoría y licencia de ONLYOFFICE del diálogo Acerca de se conservan |
| 2 | Título de la pestaña («ONLYOFFICE … Editor» → «Embitech Editor») y enlaces a www.onlyoffice.com del logo y de novedades → embitech.es | Íd. |
| 3 | Plugin «ai» fuera de la lista por defecto | El CRM tiene su propio asistente |
| 4 | Servicio `example` (editor de demostración) desactivado | No debe quedar un editor público sin autenticación |

La edición libre de la 9.4 no limita las conexiones simultáneas, así que no hace falta ningún cambio en el servidor.

---

## ⚠️ Aviso AGPL v3 — cumplimiento obligatorio

Este software está bajo **GNU Affero General Public License v3**. Al modificar el código y operar el servicio sobre la red (CRM ↔ EC2 via iframe), estás obligado a poner las fuentes modificadas a disposición de los usuarios del servicio.

**Mitigación mínima requerida**:
1. Publicar este fork en un repositorio público (no privado) y enlazarlo desde:
   - El footer del editor (`web-apps`).
   - Un endpoint `/source` o `/agpl-source` servido por Nginx que redirija al repo.
2. Mantener intactos los avisos de copyright originales de Ascensio System SIA.
3. Documentar cualquier modificación adicional (ver tabla anterior).

[texto AGPL v3 completo](https://www.gnu.org/licenses/agpl-3.0.html)

---

## Estructura

```
onlyoffice-fork/
├── docker/
│   ├── Dockerfile.full          ← imagen oficial 9.4.0.1 + branding
│   ├── branding/                ← apply-branding.sh y los logos SVG
│   ├── docker-compose.yml       ← stack local
│   ├── docker-compose.prod.yml  ← stack de la EC2
│   └── nginx-host.conf          ← nginx del host de la EC2 (TLS, cabeceras, /source)
├── scripts/
│   ├── ec2-deploy.sh            ← actualizar el editor en la EC2 sin perder ediciones
│   ├── apply-nginx-host.sh      ← instalar nginx-host.conf en la EC2 con copia y vuelta atrás
│   ├── deploy-everything.sh     ← EC2 nueva desde cero
│   ├── ec2-bootstrap.sh
│   └── build-image.ps1, up.ps1, down.ps1  ← build y stack local en Windows
├── examples/                    ← stubs para probar el editor sin el CRM
├── server, web-apps, sdkjs, core, dictionaries, core-fonts,
│   document-templates, build_tools, Docker-DocumentServer
│                                ← submódulos: código fuente oficial de la release 9.4.0, sin modificar
└── LICENSE                      ← AGPL v3 + términos adicionales de ONLYOFFICE
```

Los submódulos no hacen falta para el build; están fijados a los commits de la release para que el código fuente de lo que corre esté enlazado desde aquí (`git submodule update --init` para descargarlo).

## Build y prueba local

```bash
docker buildx build --load -f docker/Dockerfile.full -t onlyoffice-fork:local .
```

El build imprime los siete pasos del branding y termina con `OK: branding Embitech verificado`. Si una versión nueva de OnlyOffice mueve algún fichero o estilo, falla indicando qué paso.

Stack local: `docker compose -f docker/docker-compose.yml up -d` (en Windows, `scripts/up.ps1`). Healthcheck: `curl http://localhost/healthcheck` → `true`. Para probarlo con el CRM en local, el CRM tiene que firmar con el mismo `JWT_SECRET` (`ONLYOFFICE_JWT_SECRET` del backend) y el contenedor tiene que alcanzar `BACKEND_PUBLIC_URL`.

## Actualizar a otra versión de OnlyOffice

1. Cambiar la etiqueta de `FROM` en `docker/Dockerfile.full`.
2. Compilar la imagen: si el branding no encaja, el build falla.
3. Fijar los submódulos a los commits que fija `ONLYOFFICE/DocumentServer` en esa release (y `Docker-DocumentServer` a la etiqueta de la imagen).
4. Probar con el CRM en local: abrir, editar, guardar, coeditar, cerrar y convertir a PDF.
5. Desplegar con `scripts/ec2-deploy.sh` y actualizar el aviso del README con la fecha.

## Despliegue en la EC2

```bash
cd <fork> && git pull && sudo ./scripts/ec2-deploy.sh
```

Guarda la imagen en marcha como `onlyoffice-fork:anterior`, compila la nueva, ejecuta `documentserver-prepare4shutdown.sh` para que se guarden los documentos abiertos y levanta el stack. Para volver atrás: `docker tag onlyoffice-fork:anterior onlyoffice-fork:local` y `docker compose -f docker/docker-compose.prod.yml --env-file docker/.env.prod up -d`.

## Licencias

- ONLYOFFICE Docs: **AGPL v3** con los términos adicionales de Ascensio System SIA — ver [LICENSE](LICENSE).
- Modificaciones de este fork (branding y configuración): AGPL v3.
- Elementos que no son código (iconos, ilustraciones, textos): CC BY-SA 4.0 (sección 5 de los términos adicionales).

## Soporte

Este es un fork interno. Issues de upstream: [github.com/ONLYOFFICE/DocumentServer/issues](https://github.com/ONLYOFFICE/DocumentServer/issues).
