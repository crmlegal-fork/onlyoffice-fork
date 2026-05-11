# CRM Mock — sandbox del editor OnlyOffice

Mock visual del CRM (sidebar ALETHEIA + topbar + editor + panel de variables) para iterar sobre el layout y testear el editor en condiciones realistas.

Servido por un Express único en `:3000` que también provee:
- `GET /files/:name` — fuente del documento para el DocumentServer
- `GET /onlyoffice/config?file=…` — config firmado con JWT
- `POST /onlyoffice/callback` — recibe los guardados

## Arrancar

1. Asegúrate de que el stack OnlyOffice está arriba (`docker compose -f docker/docker-compose.yml ps` debe mostrar `healthy`).
2. **Copia el JWT_SECRET** de `docker/.env.local` a `.env` aquí:
   ```powershell
   cd examples\crm-mock
   Copy-Item .env.example .env
   # edita .env y pega el JWT_SECRET de docker\.env.local
   ```
3. **Pon un `sample.docx`** en `files/` (cualquier Word vale).
4. Instala deps y arranca:
   ```powershell
   npm install
   npm start
   ```
5. Abre **http://localhost:3000/**.

## Interacciones implementadas

- **Sidebar**: solo decorativo (clicks hacen `#`).
- **Topbar**: avatar, notificación, título de página.
- **Botón back**: `history.back()`.
- **Panel de variables (derecha)**:
  - **Click en una variable** → inserta el token (ej. `{{cliente.nombre}}`) en el cursor del editor vía Document Builder API connector.
  - **Buscar**: filtra la lista en vivo.
  - **Toggle grupos**: click en el header del grupo expande/colapsa.
  - **Botón ×**: oculta el panel.

## Estructura

```
crm-mock/
├── index.html      ← layout del CRM
├── style.css       ← estilos (variables CSS para el theme)
├── app.js          ← boot editor + handlers panel
├── server.js       ← Express stub (estáticos + API)
├── package.json
├── .env.example
└── files/          ← documentos editables (gitignored)
```

## Customización rápida

- **Cambiar colores**: edita las variables CSS al inicio de `style.css` (`--c-brand-dark`, `--c-brand-accent`, etc.).
- **Cambiar variables disponibles**: edita las `<li data-token="…">` en `index.html` o convierte a una fuente dinámica desde el server.
- **Cambiar branding del editor**: pasaría por modificar `web-apps` en el Dockerfile — está en el roadmap v0.2.

## Troubleshooting

- **El editor no carga**: comprueba `curl http://localhost/healthcheck` → debe devolver `true`.
- **"Download failed" en el editor**: el contenedor no resuelve `host.docker.internal`. Verifica con:
  ```powershell
  docker exec onlyoffice-ds curl -I http://host.docker.internal:3000/files/sample.docx
  ```
  Si falla, ajusta `PUBLIC_HOST` en `.env`.
- **JWT inválido**: el `JWT_SECRET` de `.env` aquí y `docker/.env.local` DEBEN ser idénticos. Si los cambias, reinicia ambos.
- **Insertar variable no hace nada**: comprueba la consola del navegador. Si el editor aún no está listo (`onDocumentReady` no ha disparado), el click se ignora.
