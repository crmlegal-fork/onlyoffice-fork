// Express stub para el CRM mock:
//   - Sirve los estáticos (index.html, style.css, app.js)
//   - GET /files/:name           → sirve el .docx fuente al DocumentServer
//   - GET /onlyoffice/config?file → devuelve config firmado con JWT
//   - POST /onlyoffice/callback  → recibe eventos (status 2/6 = guardar)
//
// Ejecutar:
//   1. cp .env.example .env  (y poner JWT_SECRET = el de docker/.env.local)
//   2. pon un sample.docx en files/
//   3. npm install
//   4. npm start
//   5. abre http://localhost:3000/

const express = require("express");
const jwt = require("jsonwebtoken");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
require("dotenv").config();

const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET;
const PUBLIC_HOST = process.env.PUBLIC_HOST || `host.docker.internal:${PORT}`;

if (!JWT_SECRET) {
  console.error("ERROR: JWT_SECRET no definido. Cópialo desde ../../docker/.env.local a .env");
  process.exit(1);
}

const FILES_DIR = path.join(__dirname, "files");
if (!fs.existsSync(FILES_DIR)) fs.mkdirSync(FILES_DIR, { recursive: true });

const app = express();
app.use(express.json({ limit: "20mb" }));

// AGPL v3 Sec. 13: enlace al código fuente del fork
app.get(["/source", "/agpl-source"], (_req, res) => {
  res.redirect(302, "https://github.com/crmlegal-fork/onlyoffice-fork");
});

// Estáticos del CRM mock
app.use(express.static(__dirname, { index: "index.html" }));

// Archivo fuente para el DocumentServer
app.get("/files/:name", (req, res) => {
  const filePath = path.join(FILES_DIR, req.params.name);
  if (!fs.existsSync(filePath)) return res.status(404).send("Not found");
  res.sendFile(filePath);
});

// Config firmado con JWT
app.get("/onlyoffice/config", (req, res) => {
  const file = req.query.file || "sample.docx";
  const filePath = path.join(FILES_DIR, file);
  if (!fs.existsSync(filePath)) return res.status(404).json({ error: "file_not_found", file });

  const stat = fs.statSync(filePath);
  const key = crypto.createHash("md5").update(file + stat.mtimeMs).digest("hex");

  const config = {
    document: {
      fileType: file.split(".").pop(),
      key,
      title: file.replace(/\.[^.]+$/, ""),
      url: `http://${PUBLIC_HOST}/files/${file}`,
      permissions: { edit: true, download: true, print: true }
    },
    documentType: detectType(file),
    editorConfig: {
      callbackUrl: `http://${PUBLIC_HOST}/onlyoffice/callback?file=${encodeURIComponent(file)}`,
      mode: "edit",
      lang: "es",
      user: { id: "demo-1", name: "ignasi Saura" },
      customization: {
        autosave: true,
        forcesave: true,
        compactToolbar: false,
        toolbarNoTabs: false,
        hideRightMenu: true,
        zoom: 100
      }
    }
  };
  config.token = jwt.sign(config, JWT_SECRET, { expiresIn: "1h" });
  res.json(config);
});

// Callback del DocumentServer
app.post("/onlyoffice/callback", async (req, res) => {
  const file = req.query.file || "unknown";
  const auth = req.headers["authorizationjwt"] || req.headers["authorization"] || "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (token) {
    try { jwt.verify(token, JWT_SECRET); }
    catch (e) { console.warn("[callback] JWT inválido:", e.message); return res.status(401).json({ error: 1 }); }
  }

  const { status, url, key, users } = req.body;
  console.log(`[callback] file=${file} status=${status} key=${key?.slice(0,8)} users=${JSON.stringify(users || [])}`);

  if (status === 2 || status === 6) {
    try {
      const fetched = await fetch(url);
      if (!fetched.ok) throw new Error("HTTP " + fetched.status);
      const buf = Buffer.from(await fetched.arrayBuffer());
      fs.writeFileSync(path.join(FILES_DIR, file), buf);
      console.log(`[callback] guardado ${file} (${buf.length} bytes)`);
    } catch (e) {
      console.error("[callback] error descargando:", e.message);
      return res.json({ error: 1 });
    }
  }
  res.json({ error: 0 });
});

function detectType(file) {
  const ext = file.split(".").pop().toLowerCase();
  if (["xlsx","xls","ods","csv"].includes(ext)) return "cell";
  if (["pptx","ppt","odp"].includes(ext)) return "slide";
  return "word";
}

app.listen(PORT, () => {
  console.log(`CRM mock listening on http://localhost:${PORT}`);
  console.log(`  Files:   ${FILES_DIR}`);
  console.log(`  Editor:  abre http://localhost:${PORT}/ en el navegador`);
  console.log(`  Public:  ${PUBLIC_HOST} (visible desde dentro del contenedor DS)`);
});
