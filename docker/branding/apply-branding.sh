#!/bin/sh
# Aplica branding "Embitech" sobre los assets oficiales de la imagen.
# Se ejecuta dentro de la imagen durante el docker build. Cada paso tiene que
# encontrar lo que cambia: si una versión de OnlyOffice mueve un fichero o un
# estilo, el build falla en vez de dejar el branding a medias.
#
# Sustituciones:
#   1. SVG del header (logo de cada editor) → "EMBITECH Editor"
#   2. SVG del diálogo Acerca de (sus textos de autoría y licencia de
#      ONLYOFFICE / Ascensio System SIA no se tocan)
#   3. Strings "ONLYOFFICE Document/Spreadsheet/… Editor" → "Embitech Editor" en HTML
#   4. Enlaces a www.onlyoffice.com (clic en el logo, novedades) → embitech.es
#   5. CSS del logo en la cabecera
#   6. Quitar el plugin "ai" de la lista por defecto
#   7. Desactivar el servicio "example" (editor demo público)

set -e
DS=/var/www/onlyoffice/documentserver
ROOT=$DS/web-apps
BRAND_DIR=/tmp/branding
BRAND_URL="https://embitech.es"
EDITORS="documenteditor spreadsheeteditor presentationeditor pdfeditor"

fail() { echo "BRANDING: $1" >&2; exit 1; }
regzip() { if [ -f "$1.gz" ]; then gzip -kf "$1"; fi; }

echo "Aplicando branding Embitech..."

# --- 1. Logos del header ---
n=0
for dir in "$ROOT"/apps/*/main/resources/img/header; do
  for variant in header-logo_s.svg dark-logo_s.svg; do
    TARGET="$dir/$variant"
    [ -f "$TARGET" ] || continue
    cp "$BRAND_DIR/$variant" "$TARGET"
    gzip -kf "$TARGET"
    n=$((n + 1))
  done
done
[ "$n" -gt 0 ] || fail "no hay logos de cabecera en apps/*/main/resources/img/header"
echo "  1. logos de cabecera: $n"

# --- 2. About logo ---
n=0
for dir in "$ROOT"/apps/*/main/resources/img/about; do
  for variant in logo_s.svg logo-white_s.svg; do
    TARGET="$dir/$variant"
    [ -f "$TARGET" ] || continue
    cp "$BRAND_DIR/about-logo_s.svg" "$TARGET"
    gzip -kf "$TARGET"
    n=$((n + 1))
  done
done
[ "$n" -gt 0 ] || fail "no hay logos de Acerca de en apps/*/main/resources/img/about"
echo "  2. logos de Acerca de: $n"

# --- 3. Strings "ONLYOFFICE X Editor" → "Embitech Editor" en HTML ---
# (regex tolerante para que tanto "ONLYOFFICE Document Editor" como "Embitech Document Editor"
#  ─si ya se aplicó branding parcial─ acaben como "Embitech Editor")
n=0
for editor in $EDITORS; do
  for f in index.html index_loader.html; do
    TARGET="$ROOT/apps/$editor/main/$f"
    [ -f "$TARGET" ] || continue
    grep -q ONLYOFFICE "$TARGET" || continue
    sed -i -E '
      s/(ONLYOFFICE|Embitech)\s+(Document|Spreadsheet|Presentation|PDF|Visio)\s+Editor/Embitech Editor/g;
      s/ONLYOFFICE/Embitech/g
    ' "$TARGET"
    regzip "$TARGET"
    n=$((n + 1))
  done
done
[ "$n" -gt 0 ] || fail "ningún index.html de los editores contiene ONLYOFFICE"
echo "  3. HTML: $n"

# --- 4. Enlaces a www.onlyoffice.com (clic en el logo, novedades) ---
# Se buscan los ficheros en vez de fijar rutas: según la versión van en el
# app.js minificado de cada editor o repartidos en Header.js, Main.js y
# Toolbar.js.
FILES=$(grep -rlE 'https?://(www\.)?onlyoffice\.com' "$ROOT"/apps/*/main --include='*.js' || true)
[ -n "$FILES" ] || fail "ningún JS de los editores enlaza a onlyoffice.com"
n=0
for TARGET in $FILES; do
  sed -i -E "s#https?://(www\.)?onlyoffice\.com[a-zA-Z0-9/._?=&-]*#${BRAND_URL}#g" "$TARGET"
  regzip "$TARGET"
  n=$((n + 1))
done
echo "  4. ficheros JS con enlaces: $n"

# --- 5. CSS: layout del logo ---
#   - ampliar contenedor de 86px → 124px (cabe "EMBITECH Editor")
#   - reducir padding-right (24px → 4px) para que no quede tanto espacio
#     entre el logo y los botones de guardar/imprimir
n=0
for editor in $EDITORS; do
  TARGET="$ROOT/apps/$editor/main/resources/css/app.css"
  [ -f "$TARGET" ] || continue
  grep -qE 'header-logo i\{[^}]*width:86px' "$TARGET" \
    || fail "no está el ancho del logo (header-logo i{…width:86px}) en $TARGET"
  grep -qE 'header-logo\{[^}]*padding:[0-9]+px 24px [0-9]+px 12px\}' "$TARGET" \
    || fail "no está el padding del logo (header-logo{…padding:Npx 24px Npx 12px}) en $TARGET"
  sed -i -E 's/(header-logo i\{[^}]*)width:86px/\1width:124px/g' "$TARGET"
  sed -i -E 's/(header-logo\{[^}]*padding:[0-9]+px )24px( [0-9]+px 12px\})/\14px\2/g' "$TARGET"
  regzip "$TARGET"
  n=$((n + 1))
done
[ "$n" -gt 0 ] || fail "ningún app.css de los editores"
echo "  5. CSS: $n"

# --- 6. Deshabilitar plugins no deseados (ej. tab "AI" del Word) ---
PLUGIN_LIST=$DS/sdkjs-plugins/plugin-list-default.json
[ -f "$PLUGIN_LIST" ] || fail "no existe $PLUGIN_LIST"
sed -i -E '/^[[:space:]]*"ai",?[[:space:]]*$/d' "$PLUGIN_LIST"
if grep -qE '"ai"' "$PLUGIN_LIST"; then fail "el plugin ai sigue en $PLUGIN_LIST"; fi
gzip -kf "$PLUGIN_LIST"
echo "  6. plugin ai fuera de la lista"

# --- 7. Deshabilitar el servicio "example" (editor demo público) ---
# Eliminamos el conf de supervisor y la referencia en el grupo ds.
# El binario y los assets siguen en la imagen pero no se arrancan ni listan.
DS_CONF=/etc/supervisor/conf.d/ds.conf
[ -f "$DS_CONF" ] || fail "no existe $DS_CONF"
rm -f /etc/supervisor/conf.d/ds-example.conf
sed -i -E 's/,example//; s/example,//; s/programs=example$/programs=/' "$DS_CONF"
if grep -q example "$DS_CONF"; then fail "example sigue en $DS_CONF"; fi
echo "  7. servicio example desactivado"

echo "Branding aplicado."
