# Cumplimiento de licencia — AGPL v3 + términos adicionales de ONLYOFFICE

Este fork de [ONLYOFFICE DocumentServer](https://github.com/ONLYOFFICE/DocumentServer) se distribuye bajo **GNU Affero General Public License v3** con los **términos adicionales** de Ascensio System SIA (final de [LICENSE](LICENSE)), igual que la release 9.4.0 de la que parte.

## Qué exige y cómo lo cumplimos

### AGPL v3 — Sección 13 ("Remote Network Interaction")

Quien usa el editor por la red tiene que poder obtener el código fuente de la versión modificada.

- El fork es público: **https://github.com/crmlegal-fork/onlyoffice-fork**. Los submódulos fijan el código oficial de la release y `docker/` contiene todas las modificaciones.
- `https://editor.embitech.cloud/source` (y `/agpl-source`) redirige al repo ([docker/nginx-host.conf](docker/nginx-host.conf)).
- El CRM muestra bajo cada editor un enlace «Código fuente» al repo.

### Término adicional 1 — Conservar avisos y atribución

- Los avisos de copyright y licencia de los ficheros fuente no se tocan: el branding solo sustituye logos SVG, el título de la pestaña, enlaces a www.onlyoffice.com y dos reglas CSS.
- El diálogo «Acerca de» del editor conserva sus textos de autoría y licencia de ONLYOFFICE / Ascensio System SIA; solo cambia el logo.

### Término adicional 2 — Avisar de que es una versión modificada, con fecha

- El [README](README.md) abre con «Versión modificada de ONLYOFFICE Docs (Document Server), desarrollado por Ascensio System SIA. Modificado por Embitech el <fecha>». La fecha se actualiza en cada cambio de versión o de branding.

### Término adicional 3 — Avisos visibles en la interfaz

La interfaz tiene que permitir (i) identificar a ONLYOFFICE como desarrollador original, (ii) saber que la versión puede estar modificada y (iii) acceder a la licencia.

- El CRM muestra bajo **todos** los editores y vistas previas (componente `DocumentEditor`): «Basado en ONLYOFFICE® Docs de Ascensio System SIA · Versión modificada por Embitech · Licencia AGPL v3 · Código fuente», con enlaces a [LICENSE](LICENSE) y al repo.
- Además, el diálogo «Acerca de» del propio editor.

### Término adicional 4 — Sin derechos de marca

- El producto se presenta como «Embitech Editor»; no usamos la marca ni el logo de ONLYOFFICE como propios.
- «ONLYOFFICE®» solo aparece como atribución del software base, que es lo que exige el término 3.

### Término adicional 5 — Contenido que no es código

- Iconos, ilustraciones y textos de ONLYOFFICE están bajo CC BY-SA 4.0. Los conservamos sin cambios salvo los logos, que sustituimos por los nuestros.

## Modificaciones aplicadas

Todas en [docker/branding/apply-branding.sh](docker/branding/apply-branding.sh), sobre la imagen oficial `onlyoffice/documentserver:9.4.0.1`:

| # | Cambio | Ficheros |
|---|---|---|
| 1 | Logo de la cabecera → «EMBITECH Editor» | [header-logo_s.svg](docker/branding/header-logo_s.svg), [dark-logo_s.svg](docker/branding/dark-logo_s.svg) |
| 2 | Logo del diálogo Acerca de | [about-logo_s.svg](docker/branding/about-logo_s.svg) |
| 3 | Título «ONLYOFFICE … Editor» → «Embitech Editor» | `index.html` de cada editor |
| 4 | Enlaces a www.onlyoffice.com (clic en el logo, novedades) → embitech.es | JS de los editores que los contienen |
| 5 | CSS: ancho del contenedor del logo 86 → 124 px, padding-right 24 → 4 px | `app.css` de cada editor |
| 6 | Plugin «ai» fuera de la lista por defecto | `sdkjs-plugins/plugin-list-default.json` |
| 7 | Servicio `example` desactivado | `/etc/supervisor/conf.d/ds.conf` |

El código del servidor no se modifica.

## Alternativa comercial

ONLYOFFICE ofrece **Developer Edition** con licencia comercial, que permite personalizar todo el branding sin las obligaciones de la AGPL. Para pasar a ella: cambiar la imagen base del Dockerfile por la que proporcionen y revisar qué partes del branding y de los avisos siguen haciendo falta según su contrato.
