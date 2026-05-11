# Cumplimiento de licencia — AGPL v3 + cláusula 7(b) OnlyOffice

Este fork de [ONLYOFFICE DocumentServer](https://github.com/ONLYOFFICE/DocumentServer) se distribuye bajo **GNU Affero General Public License v3** (la misma licencia del proyecto original).

## Qué cumplimos y cómo

### AGPL v3 — Sección 13 ("Remote Network Interaction")

> Notwithstanding any other provision of this License, if you modify the Program, your modified version must prominently offer all users interacting with it remotely through a computer network […] an opportunity to receive the Corresponding Source of your version by providing access to the Corresponding Source from a network server at no charge.

**Cómo lo cumplimos**:
- ✅ El código fuente completo del fork está publicado en: **https://github.com/crmlegal-fork/onlyoffice-fork** *(crear este repo antes de lanzar — ver más abajo)*.
- ✅ El servicio expone `https://docs.embitech.es/source` que redirige al repo.
- ✅ El CRM tiene un footer permanente con link "código fuente" → `/source`.

### Cláusula 7(b) OnlyOffice ("Retain the original Product logo")

OnlyOffice añade en cada archivo:

> Pursuant to Section 7(b) of the License you must retain the original Product logo when distributing the program.

**Cómo lo cumplimos**:
- ✅ El diálogo "About" del editor muestra "EMBITECH Editor — Powered by ONLYOFFICE®" + link al repo fuente.
- ✅ El footer del CRM muestra "Editor powered by ONLYOFFICE®".
- ✅ Los avisos de copyright en los archivos fuente (`.js`, `.css`, `Gruntfile.js`, etc.) se mantienen intactos.

### Cláusula 7(e) — Trademark

> Pursuant to Section 7(e) we decline to grant you any rights under trademark law for use of our trademarks.

**Cómo lo cumplimos**:
- ✅ NO usamos la marca "ONLYOFFICE" como nuestro producto. Nuestro producto se llama "EMBITECH Editor".
- ✅ Solo referenciamos "ONLYOFFICE®" como crédito al software base (uso descriptivo permitido, similar a "Hecho con React" o "Powered by Linux").

## Modificaciones aplicadas en este fork

Documentadas en commits + parches:

| # | Cambio | Archivo | Patch |
|---|---|---|---|
| 1 | `LICENSE_CONNECTIONS` 20 → 100 | [server/Common/sources/constants.js:91](server/Common/sources/constants.js#L91) | [patches/0001-...patch](patches/) |
| 2 | `LICENSE_USERS` 3 → 100 | [server/Common/sources/constants.js:92](server/Common/sources/constants.js#L92) | (mismo patch) |
| 3 | Logo header → "EMBITECH Editor" | [docker/branding/header-logo_s.svg](docker/branding/header-logo_s.svg) | aplicado en build |
| 4 | Logo About → "EMBITECH Editor — Powered by ONLYOFFICE®" | [docker/branding/about-logo_s.svg](docker/branding/about-logo_s.svg) | aplicado en build |
| 5 | `<title>` HTML "Embitech Editor" | sed sobre `index.html` | [docker/branding/apply-branding.sh](docker/branding/apply-branding.sh) |
| 6 | URLs `*.onlyoffice.com` → `embitech.es` | sed sobre `app.js`, `code.js` | (mismo script) |
| 7 | Plugin "ai" eliminado del listado por defecto | `plugin-list-default.json` | (mismo script) |
| 8 | CSS: ancho contenedor logo 86→124px, padding-right 24→4px | sed sobre `app.css` | (mismo script) |

Toda la versión upstream usada: **`v9.3.1.11`** del repo `ONLYOFFICE/server` (y mismos tags en `core`, `web-apps`, `sdkjs`, etc.).

---

## Cómo publicar el repo público (TODO antes de ir a producción)

Esto es **obligatorio** antes de exponer el editor a usuarios externos. Pasos:

### 1. Crear cuenta de organización (o repo personal) en GitHub

Si no existe ya, crea la organización **embitech** en https://github.com/organizations/new (gratuita para repos públicos).

### 2. Crear repo público `onlyoffice-fork`

En la organización embitech (o tu usuario), crea **un repo público vacío** llamado `onlyoffice-fork`. NO incluir README ni licencia inicial — los aporta el push siguiente.

### 3. Inicializar git y push desde tu Windows local

```powershell
cd C:\Users\ignasi\Desktop\Onlyoffice

# Solo lo NUESTRO: server con parche + docker + scripts + patches + docs.
# NO commiteamos core/, web-apps/, sdkjs/, etc. (son submódulos upstream sin modificar).
# El .gitignore que creamos ya los excluye.

git init
git branch -m main
git add server docker scripts patches examples DEPLOY.md README.md LICENSE_COMPLIANCE.md .gitattributes .gitignore .dockerignore

git -c user.email="dev@embitech.es" -c user.name="Embitech" commit -m "Initial fork: OnlyOffice DocumentServer v9.3.1.11 + Embitech branding + lifted connection cap"

# Sustituye con la URL real de tu repo GitHub
git remote add origin https://github.com/crmlegal-fork/onlyoffice-fork.git
git push -u origin main
```

### 4. Añadir LICENSE en el repo

Crea `LICENSE` en el root del repo con el texto AGPL v3 completo (https://www.gnu.org/licenses/agpl-3.0.txt).

### 5. (Opcional) Verificar accesibilidad

Desde una sesión incógnito en el navegador, abre https://github.com/crmlegal-fork/onlyoffice-fork → debe ser accesible sin login.

### 6. Verificar redirecciones desde el editor

Una vez la imagen esté en EC2 con el nginx-host.conf actualizado, probar:
```
curl -I https://docs.embitech.es/source
# → HTTP 302 Location: https://github.com/crmlegal-fork/onlyoffice-fork
```

---

## Si en el futuro decides white-labeling oficial

OnlyOffice ofrece **Developer Edition** con licencia para personalizar 100% el branding (sin obligación AGPL, sin "Powered by"):

- Página: https://www.onlyoffice.com/docs-developer.aspx
- Precio orientativo: ~$2-5k/año según conexiones simultáneas.

Si lo contratas:
1. En `docker/branding/apply-branding.sh` quita los blocks `--- 2. About logo` y la línea de "Powered by ONLYOFFICE®" del SVG.
2. Borra este `LICENSE_COMPLIANCE.md` y el footer legal del CRM mock.
3. Borra el endpoint `/source` del nginx + Express stub.
4. Cambia la imagen Docker base de `onlyoffice/documentserver:9.3.1.2` a la versión Developer Edition que te proporcionen.
