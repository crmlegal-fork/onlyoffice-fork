# OnlyOffice DocumentServer — fork interno

Fork del [OnlyOffice DocumentServer](https://github.com/ONLYOFFICE/DocumentServer) (AGPL v3) para integración con CRM propio. Editores Word, Excel y PDF servidos desde EC2 vía iframe.

> **Tag base de upstream**: `v9.3.1.11`
> **Imagen Docker base (runtime)**: `onlyoffice/documentserver:9.3.1.2`

## Modificaciones aplicadas

| # | Cambio | Archivo | Justificación |
|---|---|---|---|
| 1 | `LICENSE_CONNECTIONS` 20 → 100 | [server/Common/sources/constants.js:91](server/Common/sources/constants.js#L91) | Eliminar tope de 20 conexiones del Community Edition para soportar hasta ~50 usuarios concurrentes con holgura |
| 2 | `LICENSE_USERS` 3 → 100 | [server/Common/sources/constants.js:92](server/Common/sources/constants.js#L92) | Coherencia con (1) |

Los parches se mantienen también en [patches/](patches/) como `git format-patch` files re-aplicables.

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
Onlyoffice\
├── server\                  ← FORK (parcheado, branch feature/lift-connection-limit)
├── core\                    ← upstream v9.3.1.11 (sin modificar)
├── web-apps\                ← upstream v9.3.1.11
├── sdkjs\                   ← upstream v9.3.1.11
├── dictionaries\            ← upstream
├── core-fonts\              ← upstream
├── document-templates\      ← upstream
├── build_tools\             ← upstream (orquestador de build)
├── Docker-DocumentServer\   ← upstream (Dockerfile oficial - referencia)
├── docker\
│   ├── Dockerfile.full      ← multi-stage build de NUESTRA imagen
│   ├── docker-compose.yml
│   ├── .dockerignore
│   └── .env.local           ← JWT_SECRET (NO commitear)
├── scripts\
│   ├── clone-all.ps1        ← clona/actualiza todos los repos en una tag
│   ├── apply-patches.ps1    ← reaplica patches/ idempotentemente
│   ├── build-image.ps1      ← docker buildx build de la imagen
│   ├── up.ps1               ← levanta el stack
│   └── down.ps1             ← para el stack
├── patches\                 ← parches portables como format-patch
├── examples\crm-integration\← stub Express + HTML para probar el editor
└── README.md
```

## Quickstart (Windows + Docker Desktop)

### Pre-requisitos
- Docker Desktop con backend WSL2.
- WSL2 con ≥8 GB RAM (`%UserProfile%\.wslconfig`).
- Git para Windows con `core.longpaths=true` y `core.autocrlf=input`.
- Windows Defender excluyendo este directorio (acelera builds 10×).

### 1) Clonar todos los repos
```powershell
.\scripts\clone-all.ps1
```
Si los repos ya existen, los reposiciona en la tag por defecto (`v9.3.1.11`).

### 2) Aplicar parches (idempotente)
```powershell
.\scripts\apply-patches.ps1
```
Salta los que ya están aplicados.

### 3) Build de la imagen
```powershell
.\scripts\build-image.ps1
```
Primer build: 10-20 min (npm install + grunt). Builds incrementales: 2-5 min.

### 4) Levantar stack
```powershell
.\scripts\up.ps1
```
- Genera `docker\.env.local` con un `JWT_SECRET` aleatorio si no existe.
- Espera hasta `healthy` (~2 min en cold start).
- Imprime URLs útiles.

### 5) Probar end-to-end
```powershell
cd examples\crm-integration
Copy-Item .env.example .env  # y editar el JWT_SECRET con el de docker/.env.local
npm install
npm start
# en otra terminal:
python -m http.server 8080
```
Abrir `http://localhost:8080/index.html`.

## Verificación del parche

```powershell
# El parche debe estar compilado en la imagen (no overrideado por volumen):
docker run --rm onlyoffice-fork:local node -e "console.log(require('/var/www/onlyoffice/documentserver/server/Common/sources/constants.js').LICENSE_CONNECTIONS)"
# esperado: 100

# Healthcheck:
curl http://localhost/healthcheck
# esperado: true
```

## Despliegue a EC2 (siguiente iteración)

1. Build → `docker tag onlyoffice-fork:local <ECR>/onlyoffice-fork:1.0.0 && docker push ...`
2. Compose en EC2 con misma config + Nginx host-side haciendo TLS termination con tu cert.
3. Volúmenes en EBS gp3 ≥40 GB.
4. Security group: 443 público, 80 cerrado, 22 admin-only.

## Roadmap

- [x] v0.1: Parche límite 20 → 100 conexiones, build desde fuente del módulo `server`.
- [ ] v0.2: Build de `web-apps` y `sdkjs` desde fuente (para customizar UI/branding).
- [ ] v0.3: Despliegue automatizado a EC2 (Terraform / CDK).
- [ ] v0.4: Hardening JWT (rotación, allowlist orígenes, rate limiting).
- [ ] v0.5: Build del módulo `core` C++ (solo si hace falta tocar el motor).

## Licencias

- OnlyOffice DocumentServer: **AGPL v3** — ver [LICENSE.txt](server/LICENSE.txt).
- Modificaciones de este fork: AGPL v3 (heredado).
- Todo el código del editor (interfaces, iconos, doc): CC BY-SA 4.0 — ver Gruntfile original.

## Soporte

Este es un fork interno. Issues de upstream: [github.com/ONLYOFFICE/DocumentServer/issues](https://github.com/ONLYOFFICE/DocumentServer/issues).
