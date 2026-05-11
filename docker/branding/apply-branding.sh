#!/bin/sh
# Aplica branding "Embitech" sobre los assets oficiales de la imagen.
# Se ejecuta dentro del runtime stage durante el docker build.
#
# Sustituciones:
#   1. SVG del header (logo de cada editor) → "EMBITECH Editor"
#   2. SVG del About dialog
#   3. Strings "ONLYOFFICE Document/Spreadsheet/… Editor" → "Embitech Editor" en HTML
#   4. URLs "www.onlyoffice.com" → "embitech.com" en app.js de cada editor

set -e
ROOT=/var/www/onlyoffice/documentserver/web-apps
BRAND_DIR=/tmp/branding
BRAND_URL="https://embitech.es"

echo "Aplicando branding Embitech..."

# --- 1. Logos del header (todas las apps) ---
for editor in documenteditor spreadsheeteditor presentationeditor pdfeditor visioeditor; do
  for variant in header-logo_s.svg dark-logo_s.svg; do
    TARGET="$ROOT/apps/$editor/main/resources/img/header/$variant"
    if [ -f "$TARGET" ]; then
      cp "$BRAND_DIR/$variant" "$TARGET"
      gzip -kf "$TARGET"
    fi
  done
done
# Common header (el principal usado por todos los editores)
for variant in header-logo_s.svg dark-logo_s.svg; do
  TARGET="$ROOT/apps/common/main/resources/img/header/$variant"
  if [ -f "$TARGET" ]; then
    cp "$BRAND_DIR/$variant" "$TARGET"
    gzip -kf "$TARGET"
  fi
done

# --- 2. About logo ---
for editor in documenteditor spreadsheeteditor presentationeditor pdfeditor visioeditor common; do
  for variant in logo_s.svg logo-white_s.svg; do
    TARGET="$ROOT/apps/$editor/main/resources/img/about/$variant"
    if [ -f "$TARGET" ]; then
      cp "$BRAND_DIR/about-logo_s.svg" "$TARGET"
      gzip -kf "$TARGET"
    fi
  done
done

# --- 3. Strings "ONLYOFFICE X Editor" → "Embitech Editor" en HTML ---
# (regex tolerante para que tanto "ONLYOFFICE Document Editor" como "Embitech Document Editor"
#  ─si ya se aplicó branding parcial─ acaben como "Embitech Editor")
for editor in documenteditor spreadsheeteditor presentationeditor pdfeditor; do
  for f in index.html index_loader.html; do
    TARGET="$ROOT/apps/$editor/main/$f"
    if [ -f "$TARGET" ]; then
      sed -i -E '
        s/(ONLYOFFICE|Embitech)\s+(Document|Spreadsheet|Presentation|PDF|Visio)\s+Editor/Embitech Editor/g;
        s/ONLYOFFICE/Embitech/g
      ' "$TARGET"
      [ -f "$TARGET.gz" ] && gzip -kf "$TARGET"
    fi
  done
done

# --- 4. URLs en app.js y code.js (apuntan a onlyoffice.com en click logo, "what's new", help) ---
for editor in documenteditor spreadsheeteditor presentationeditor pdfeditor; do
  for f in app.js code.js; do
    TARGET="$ROOT/apps/$editor/main/$f"
    if [ -f "$TARGET" ]; then
      sed -i -E "
        s#https?://(www\.)?onlyoffice\.com[a-zA-Z0-9/._?=&-]*#${BRAND_URL}#g
      " "$TARGET"
      [ -f "$TARGET.gz" ] && gzip -kf "$TARGET"
    fi
  done
done

# --- 5. CSS: layout del logo ---
#   - ampliar contenedor de 86px → 124px (cabe "EMBITECH Editor")
#   - reducir padding-right (24px → 8px) para que no quede tanto espacio
#     entre el logo y los botones de guardar/imprimir
for editor in documenteditor spreadsheeteditor presentationeditor pdfeditor; do
  TARGET="$ROOT/apps/$editor/main/resources/css/app.css"
  if [ -f "$TARGET" ]; then
    # width del SVG (solo dentro de la regla "header-logo i{...}")
    sed -i -E 's/(header-logo i\{[^}]*)width:86px/\1width:124px/g' "$TARGET"
    # padding-right LTR: header-logo{...padding:Npx 24px Npx 12px} → 4px en posición 2
    sed -i -E 's/(header-logo\{[^}]*padding:[0-9]+px )24px( [0-9]+px 12px\})/\14px\2/g' "$TARGET"
    [ -f "$TARGET.gz" ] && gzip -kf "$TARGET"
  fi
done

# --- 6. Deshabilitar plugins no deseados (ej. tab "AI" del Word) ---
PLUGIN_LIST=/var/www/onlyoffice/documentserver/sdkjs-plugins/plugin-list-default.json
if [ -f "$PLUGIN_LIST" ]; then
  # Eliminar la línea "ai", (con o sin coma trailing)
  sed -i -E '/^[[:space:]]*"ai",?[[:space:]]*$/d' "$PLUGIN_LIST"
  gzip -kf "$PLUGIN_LIST"
fi

echo "Branding aplicado."
