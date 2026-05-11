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
wireVariablesPanel();

async function bootEditor() {
  try {
    const cfg = await fetchConfig("sample.docx");
    document.getElementById("doc-title").textContent = cfg.document.title;
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

// =============== Panel de variables ===============
function wireVariablesPanel() {
  // Toggle grupos
  document.querySelectorAll(".vars-group-header").forEach((h) => {
    h.addEventListener("click", () => h.parentElement.classList.toggle("vars-group--collapsed"));
  });

  // Click en variable → insertar en el cursor
  document.querySelectorAll(".vars-list li").forEach((li) => {
    li.addEventListener("click", () => insertToken(li.dataset.token));
  });

  // Búsqueda
  const search = document.getElementById("vars-search");
  search.addEventListener("input", () => {
    const q = search.value.trim().toLowerCase();
    document.querySelectorAll(".vars-list li").forEach((li) => {
      const t = li.textContent.toLowerCase();
      li.style.display = !q || t.includes(q) ? "" : "none";
    });
  });

  // Botón cerrar panel
  document.getElementById("vars-close").addEventListener("click", () => {
    document.getElementById("vars-panel").style.display = "none";
  });
}

function insertToken(token) {
  if (!editor) {
    console.warn("editor no listo aún");
    return;
  }
  // Usar el connector de la Document Builder API para insertar texto en el cursor
  const connector = editor.createConnector();
  connector.callCommand(function () {
    const oDocument = Api.GetDocument();
    const oRange = oDocument.GetRangeBySelect();
    if (oRange) {
      oRange.AddText(arguments[0]);
    } else {
      oDocument.InsertContent([Api.CreateRun().AddText(arguments[0])]);
    }
  }, false, false, [token]);
}
