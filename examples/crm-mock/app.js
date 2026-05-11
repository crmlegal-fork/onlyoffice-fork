// app.js — boot del editor OnlyOffice + interacciones del panel de variables
//
// Flujo:
//   1. fetch /onlyoffice/config?file=sample.docx → config firmado con JWT
//   2. cargar dinámicamente el script /web-apps/apps/api/documents/api.js del DocumentServer
//   3. new DocsAPI.DocEditor("editor", cfg) → monta el iframe del editor
//   4. al hacer click en una variable del panel, ejecutar callCommand para insertar texto

const DS_BASE = "http://localhost";  // DocumentServer (Docker en :80)
let editor = null;

bootEditor();

async function bootEditor() {
  try {
    const cfg = await fetchConfig("sample.docx");
    document.title = cfg.document.title + " — Embitech Editor";
    await loadScript(`${DS_BASE}/web-apps/apps/api/documents/api.js`);
    editor = new DocsAPI.DocEditor("editor", {
      ...cfg,
      width: "100%",
      height: "100%",
      events: {
        onDocumentReady: () => console.log("[editor] ready"),
        onError: (e) => console.error("[editor] error", e),
      }
    });
  } catch (err) {
    showError(err.message + "\n\n¿Está el stack arriba? Verifica con:\n  curl http://localhost/healthcheck");
  }
}

async function fetchConfig(file) {
  const r = await fetch(`/onlyoffice/config?file=${encodeURIComponent(file)}`);
  if (!r.ok) throw new Error(`config endpoint HTTP ${r.status}`);
  return r.json();
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const s = document.createElement("script");
    s.src = src;
    s.onload = resolve;
    s.onerror = () => reject(new Error("No se pudo cargar " + src));
    document.head.appendChild(s);
  });
}

function showError(msg) {
  const el = document.getElementById("editor");
  el.innerHTML = `<div class="editor-error">${msg}</div>`;
}

