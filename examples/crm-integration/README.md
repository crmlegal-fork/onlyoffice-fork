# Stub CRM — integración OnlyOffice fork

Demo mínima de integración: un servidor Express que simula el lado CRM (sirve un `.docx`, firma el config con JWT, recibe el callback) + un HTML estático que carga el editor en iframe.

## Setup

1. Asegúrate de que el stack OnlyOffice está arriba (`scripts\up.ps1` desde la raíz).
2. Copia el JWT_SECRET de `docker/.env.local` a este directorio:
   ```powershell
   Copy-Item .env.example .env
   # Edita .env y pega el JWT_SECRET (mismo que en docker/.env.local)
   ```
3. Pon un documento de prueba: `files/sample.docx` (Word vacío sirve).
4. Instala deps y arranca:
   ```powershell
   npm install
   npm start
   ```
5. Sirve `index.html` en otro puerto (no puede ser 3000):
   ```powershell
   python -m http.server 8080
   # o cualquier servidor estático
   ```
6. Abre `http://localhost:8080/index.html` → debería cargar el editor con sample.docx.

## Cómo funciona

```
Browser ─► localhost:8080/index.html
   │
   └── fetch ─► localhost:3000/onlyoffice/config?file=sample.docx
                  └── responde { document, editorConfig, token: JWT(payload) }
   │
   └── carga ─► localhost/web-apps/apps/api/documents/api.js (DocumentServer)
   │
   └── new DocsAPI.DocEditor(...) ─► iframe del editor

DocumentServer (contenedor)
   │
   └── descarga ─► host.docker.internal:3000/files/sample.docx  (sirve Express)
   │
   └── al guardar ─► POST host.docker.internal:3000/onlyoffice/callback
                        status=2, url=https://docs/.../result.docx
                        Express descarga la url y sobrescribe sample.docx
```

## Troubleshooting

- **El editor muestra "Download failed"**: el contenedor no puede resolver `host.docker.internal`. Verifica con:
  ```powershell
  docker exec onlyoffice-ds curl -I http://host.docker.internal:3000/files/sample.docx
  ```
- **JWT inválido**: revisa que `JWT_SECRET` coincida en `docker/.env.local` y `examples/crm-integration/.env`. Si cambias uno, reinicia ambos.
- **CORS**: el HTML estático puede dar errores CORS si lo sirves desde `file://`. Usa siempre un servidor HTTP (python -m http.server, npx serve, etc.).
