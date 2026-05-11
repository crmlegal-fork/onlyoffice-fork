// Stub Express que simula el lado CRM:
//   - GET /files/:name           → sirve el .docx fuente
//   - GET /onlyoffice/config?file → devuelve el config firmado con JWT para el editor
//   - POST /onlyoffice/callback  → recibe los eventos del DocumentServer
//                                  (status 2 = guardar)
//
// Ejecutar:
//   1. cp .env.example .env  (y poner JWT_SECRET igual al de docker/.env.local)
//   2. npm install
//   3. npm start

const express = require("express");
const jwt = require("jsonwebtoken");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
require("dotenv").config();

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET;
const PUBLIC_HOST = process.env.PUBLIC_HOST || "host.docker.internal:3000";

if (!JWT_SECRET) {
  console.error("ERROR: JWT_SECRET no está definido. Cópialo desde docker/.env.local a .env");
  process.exit(1);
}

const FILES_DIR = path.join(__dirname, "files");
if (!fs.existsSync(FILES_DIR)) fs.mkdirSync(FILES_DIR, { recursive: true });

const app = express();
app.use(express.json({ limit: "10mb" }));

// Servir el documento de muestra
app.get("/files/:name", (req, res) => {
  const filePath = path.join(FILES_DIR, req.params.name);
  if (!fs.existsSync(filePath)) {
    return res.status(404).send("Not found: " + req.params.name);
  }
  res.sendFile(filePath);
});

// Generar config firmado para el editor
app.get("/onlyoffice/config", (req, res) => {
  const file = req.query.file || "sample.docx";
  const filePath = path.join(FILES_DIR, file);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: "file_not_found", file });
  }
  // key debe ser único por versión del documento (cambiar al modificar)
  const key = crypto.createHash("md5").update(file + fs.statSync(filePath).mtimeMs).digest("hex");
  const config = {
    document: {
      fileType: file.split(".").pop(),
      key,
      title: file,
      url: `http://${PUBLIC_HOST}/files/${file}`
    },
    documentType: detectType(file),
    editorConfig: {
      callbackUrl: `http://${PUBLIC_HOST}/onlyoffice/callback?file=${encodeURIComponent(file)}`,
      mode: "edit",
      lang: "es"
    }
  };
  // Token JWT firma el config completo
  config.token = jwt.sign(config, JWT_SECRET, { expiresIn: "1h" });
  res.json(config);
});

// Callback del DocumentServer
// Estados: 0 sin cambio, 1 editando, 2 guardar, 3 error guardado, 4 cerrado sin cambios,
//          6 forzar guardar, 7 error en force save
app.post("/onlyoffice/callback", async (req, res) => {
  const file = req.query.file || "unknown";
  // Validar JWT del header (DocumentServer lo manda como AuthorizationJwt)
  const auth = req.headers["authorizationjwt"] || "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (token) {
    try { jwt.verify(token, JWT_SECRET); }
    catch (e) {
      console.warn("[callback] JWT inválido:", e.message);
      return res.status(401).json({ error: 1, reason: "jwt_invalid" });
    }
  }

  const { status, url, key, users } = req.body;
  console.log(`[callback] file=${file} status=${status} key=${key?.slice(0,8)} users=${JSON.stringify(users || [])}`);

  if (status === 2 || status === 6) {
    // Descargar el archivo guardado y persistir
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
  if (["docx","doc","odt","rtf","txt","pdf"].includes(ext)) return "word";
  if (["xlsx","xls","ods","csv"].includes(ext)) return "cell";
  if (["pptx","ppt","odp"].includes(ext)) return "slide";
  return "word";
}

app.listen(PORT, () => {
  console.log(`CRM stub listening on :${PORT}`);
  console.log(`  Demo:     http://localhost:${PORT.toString().replace('3000','')}/index.html (sirve desde python -m http.server u otra)`);
  console.log(`  Files:    ${FILES_DIR}`);
  console.log(`  Public:   http://${PUBLIC_HOST}`);
});
