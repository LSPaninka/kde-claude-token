# Uso de Claude / Codex — barra de menús de macOS 26

Reimplementación nativa en **Swift (SwiftUI + AppKit)** de los plasmoides de KDE
*Uso de Claude* y *Uso de Codex*, para **macOS 26 (Tahoe)**. El plasmoide
separador se ha ignorado a propósito.

Cada widget vive como un **ítem de la barra de menús** (`NSStatusItem`):

- **Versión minimalista (barra de menús):** anillos con el porcentaje en el
  centro y, a su lado, la hora de reinicio.
  - Claude → dos anillos: `5h` (`HH:MM`) y semanal (`ddd HH:MM`).
  - Codex → un anillo semanal (`ddd HH:MM`).
- **Versión grande (al hacer clic):** un popover (`NSPopover`) con barras o
  anillos detallados, encabezado, botón de actualizar y pie con la última
  actualización o el error.

Sigue la especificación de [`../SPEC.md`](../SPEC.md): mismo modelo de datos,
formato, colores por defecto, ciclo de actualización y gestos.

## Requisitos

- macOS 26 o superior.
- Xcode 26 / toolchain de Swift correspondiente (`swift` en el `PATH`).
- Haber iniciado sesión con las CLIs correspondientes:
  - **Claude Code** → en macOS guarda el token en el **Keychain** (ítem de
    contraseña genérica con servicio `Claude Code-credentials`). La app lo lee
    de ahí automáticamente. Como respaldo también acepta el archivo
    `~/.claude/.credentials.json` (Linux / versiones antiguas) o una ruta fijada
    a mano en *Ajustes*.
  - **Codex** → `${CODEX_HOME:-~/.codex}/auth.json`.

  > La primera vez que la app lee el ítem del Keychain, macOS mostrará un
  > diálogo pidiendo permiso para acceder a `Claude Code-credentials`. Pulsa
  > **Permitir siempre**. (Al recompilar sin firma estable, el sistema puede
  > volver a preguntar.)

## Compilar y ejecutar

```bash
cd macos
swift run          # compila y lanza la app (aparece en la barra de menús)
```

Para una compilación de release:

```bash
swift build -c release
.build/release/ClaudeCodexUsage
```

### En segundo plano

`run.sh` compila en release y deja la app corriendo desacoplada de la terminal:

```bash
./run.sh          # build + (re)lanzar en segundo plano
./run.sh stop     # detener la instancia
./run.sh restart  # stop + build + lanzar
./run.sh log      # seguir el log en vivo
```

La app es de tipo *accesorio*: no muestra icono en el Dock ni ventana principal,
solo los ítems de la barra de menús.

## Gestos

| Gesto | Acción |
|---|---|
| **Clic izquierdo** | Abrir/cerrar el popover con la vista completa. |
| **Clic central** | Actualizar de inmediato, sin abrir el popover. |
| **Clic derecho** | Menú contextual: *Actualizar*, *Ajustes…*, *Salir*. |

## Ajustes

Menú contextual → *Ajustes…* abre una ventana con dos pestañas (Claude / Codex).
Las claves, tipos y valores por defecto coinciden con los del plasmoide de KDE
(§5 de `SPEC.md`) y se guardan en `UserDefaults`.

## Notas de implementación

- **Sin `curl`/`jq`:** se lee el archivo de credenciales en local y se hace la
  petición con `URLSession`, fijando las cabeceras exactas (incluido
  `User-Agent`). El token solo se envía a su host (`api.anthropic.com` /
  `chatgpt.com`).
- **Dibujo:** anillos y barras con `Canvas`/`Shape` de SwiftUI (§6 de `SPEC.md`).
- **Barra de menús:** la vista compacta se dibuja a `NSImage` (con color) y se
  usa como `button.image` del `NSStatusItem` (montaje vanilla). Así la altura del
  botón la controla el sistema y el popover queda pegado a la barra. El popover
  usa un `contentSize` fijo y sin animación para que no se desfase al refrescar.
- **Estructura del código:**
  - `Format.swift` — formato puro (port de `format.js`).
  - `Model.swift` — modelo normalizado, errores, parseo de fechas.
  - `ColorHex.swift` — conversión color ↔ `#AARRGGBB`.
  - `Settings.swift` — configuración persistente por widget.
  - `Networking.swift` — lectura de credenciales y clientes HTTP.
  - `UsageStore.swift` — sondeo, reloj y máquina de estados.
  - `Views/` — `RingChart`, `UsageBar`, vistas compactas y completas, ajustes.
  - `StatusController.swift` — `NSStatusItem` + `NSPopover` + gestos.
  - `App.swift` / `main.swift` — arranque.
