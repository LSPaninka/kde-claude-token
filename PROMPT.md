# Prompt: portar plasmoides de Plasma 5 a Plasma 6

## Cómo usarlo

1. Abre una **sesión nueva** de Claude Code sobre el repositorio del plasmoide
   que quieras portar y elige el modelo **Sonnet**.
2. Copia todo lo que hay entre las líneas `COPIAR DESDE AQUÍ` y `HASTA AQUÍ` y
   pégalo como primer mensaje.
3. Si en ese repo hay varios plasmoides, el prompt los porta todos. Si sólo
   quieres uno, añade al final: «Porta sólo `<carpeta>`».

El prompt está basado en el port real de este repositorio (rama
`claude/plasma6-port` de `LSPaninka/kde-claude-token`), que se verificó con el
arnés de `tools/qml-harness/`.

---

<!-- ======================= COPIAR DESDE AQUÍ ======================= -->

Quiero portar los plasmoides de este repositorio de **KDE Plasma 5** a **KDE
Plasma 6**. Actualicé mi equipo y ahora, al añadirlos, Plasma muestra:
«Este elemento gráfico fue escrito para una versión de Plasma más antigua y no
es compatible con Plasma 6».

**Mi sistema:** Kubuntu 26.04 LTS, KDE Plasma 6.6.6, KDE Frameworks 6.24, Qt
6.10.2, Wayland.

## Reglas

- Crea una **rama nueva** a partir de la actual (p. ej. `claude/plasma6-port`).
  La rama actual se queda como versión para Plasma 5: no la modifiques.
- El comportamiento visible debe quedar **idéntico**: mismas funciones, misma
  configuración (mismas claves y valores por defecto), mismos textos.
- **No cambies el `Id` del plugin**, para que se actualice en su sitio y
  conserve la configuración del usuario. Sube sólo la versión.
- No añadas dependencias nuevas. Usa sólo módulos que vienen con Plasma 6 / Qt 6.
- Respeta el estilo del código existente (idioma de los comentarios, nombres).
- No inventes APIs. Ante la duda, consulta la guía oficial:
  https://develop.kde.org/docs/plasma/widget/porting_kf6/
- Al terminar: commit con un mensaje claro, push de la rama nueva y un resumen.

## Paso 1 — Inventario

Antes de cambiar nada, localiza todo lo que depende de Plasma 5 / Qt 5:

```bash
grep -rnE "^import .* [0-9]+\.[0-9]+|plasmoid\.|Plasmoid\.|PlasmaCore\.|PlasmaComponents|PlasmaExtras|units\.|theme\.|DataSource|onNewData|QtGraphicalEffects|QtQuick\.Dialogs|QtQuick\.Controls 1|ColorDialog|FileDialog|iconSource|IconItem|SvgItem|FrameSvg|ColorScope|setAction|nativeInterface" --include=*.qml --include=*.js .
find . -name metadata.desktop -o -name metadata.json -o -name main.xml -o -name config.qml
```

## Paso 2 — Cambios (aplica los que correspondan)

### A. Metadatos: `metadata.desktop` → `metadata.json`
Plasma 6 **sólo lee `metadata.json`** y exige `X-Plasma-API-Minimum-Version`.
Sin este campo aparece exactamente el error de arriba. Borra
`metadata.desktop` y crea:

```json
{
    "KPlugin": {
        "Authors": [{ "Name": "<X-KDE-PluginInfo-Author>", "Email": "<X-KDE-PluginInfo-Email>" }],
        "Category": "<X-KDE-PluginInfo-Category>",
        "Description": "<Comment>",
        "Description[es]": "<Comment[es]>",
        "EnabledByDefault": true,
        "Icon": "<Icon>",
        "Id": "<X-KDE-PluginInfo-Name>  (¡el mismo!)",
        "License": "<X-KDE-PluginInfo-License>",
        "Name": "<Name>",
        "Name[es]": "<Name[es]>",
        "Version": "<sube la versión mayor>",
        "Website": "<X-KDE-PluginInfo-Website>"
    },
    "KPackageStructure": "Plasma/Applet",
    "X-Plasma-API-Minimum-Version": "6.0"
}
```
El script principal debe ser `contents/ui/main.qml`. Si `X-Plasma-MainScript`
apuntaba a otro archivo, renómbralo.

### B. Imports sin versión (Qt 6)
`import QtQuick 2.15` → `import QtQuick`, y lo mismo con `QtQuick.Layouts`,
`QtQuick.Controls`, `QtQuick.Window`, `QtQuick.Dialogs`,
`org.kde.plasma.plasmoid`, `org.kde.plasma.core`, `org.kde.plasma.components`,
`org.kde.plasma.extras`, `org.kde.kirigami`, `org.kde.plasma.configuration`.
Mantén los alias (`as PlasmaCore`, etc.).

### C. Raíz del applet: `PlasmoidItem`
- El objeto raíz de `main.qml` pasa de `Item { … }` a `PlasmoidItem { … }`.
- Estas propiedades pasan a ser del `PlasmoidItem` y **pierden el prefijo
  `Plasmoid.`**: `compactRepresentation`, `fullRepresentation`,
  `preferredRepresentation` (p. ej. `preferredRepresentation: fullRepresentation`),
  `switchWidth`, `switchHeight`, `toolTipMainText`, `toolTipSubText`,
  `toolTipTextFormat`, `hideOnWindowDeactivate`, `compactRepresentationItem`,
  `fullRepresentationItem`, `expanded`.
- `plasmoid.expanded = …` → `root.expanded = …` (`root` = id del `PlasmoidItem`).
- El objeto de contexto en minúsculas `plasmoid` ya no existe. Usa el adjunto
  **`Plasmoid`**: `plasmoid.configuration.x` → `Plasmoid.configuration.x`;
  ídem `formFactor`, `location`, `immutable`, `icon`, `title`, `status`,
  `backgroundHints`. Cualquier archivo que use `Plasmoid` necesita
  `import org.kde.plasma.plasmoid`, también los componentes auxiliares.
- `plasmoid.nativeInterface` → `Plasmoid`.
- Acciones de menú: `plasmoid.setAction(...)` / `plasmoid.action(...)` →
  `Plasmoid.contextualActions: [ PlasmaCore.Action { text: …; icon.name: …; onTriggered: … } ]`.
- Un applet que debe dibujarse **directamente en el panel** (sin icono ni
  ventana emergente) debe declarar un `fullRepresentation` explícito y
  `preferredRepresentation: fullRepresentation`.

### D. DataEngines → `Plasma5Support`
`PlasmaCore.DataSource` ya no existe en `org.kde.plasma.core`:
```qml
import org.kde.plasma.plasma5support as Plasma5Support
Plasma5Support.DataSource { id: src; engine: "executable"; … }
```
En los manejadores, cualifica los métodos con el id
(`src.disconnectSource(sourceName)`).

### E. Qt 6: parámetros explícitos en los manejadores de señales
La inyección implícita de parámetros está obsoleta. Hazlos explícitos:
- `onNewData: { … data … sourceName … }` → `onNewData: (sourceName, data) => { … }`
- `onClicked: { … mouse.button … }` → `onClicked: (mouse) => { … }` (ídem `onPressed`, `onWheel: (wheel) =>`, `Keys.onPressed: (event) =>`)
- Señales propias con argumentos, p. ej. `onPicked: x = hex` → `onPicked: (hex) => x = hex`

### F. `PlasmaCore` → Kirigami / KSvg
- `PlasmaCore.Units.*` y el global `units.*` → `Kirigami.Units.*`
- `PlasmaCore.Theme.*` y el global `theme.*` → `Kirigami.Theme.*`
  (`smallestFont` → `Kirigami.Theme.smallFont`, `defaultFont` → `Kirigami.Theme.defaultFont`)
- `PlasmaCore.IconItem` → `Kirigami.Icon`
- `PlasmaCore.Svg` / `SvgItem` / `FrameSvgItem` → `import org.kde.ksvg as KSvg`
  y `KSvg.SvgItem { imagePath: "…"; elementId: "…" }` / `KSvg.FrameSvgItem`
- `PlasmaCore.ColorScope` → `Kirigami.Theme.colorSet` / `Kirigami.Theme.inherit`
- Se mantienen en `org.kde.plasma.core`: `PlasmaCore.Types`, `PlasmaCore.ToolTipArea`,
  `PlasmaCore.Dialog`, `PlasmaCore.Action`.

### G. Componentes
- PlasmaComponents 2 → PlasmaComponents 3 (`import org.kde.plasma.components`),
  basado en QtQuick.Controls 2: `iconSource`/`iconName` → `icon.name`;
  `tooltip` → `QQC2.ToolTip.text` + `QQC2.ToolTip.visible: hovered`.
- QtQuick.Controls 1 → QtQuick.Controls 2.
- `QtGraphicalEffects` → `Qt5Compat.GraphicalEffects` (o `MultiEffect` de QtQuick.Effects).
- `QtQuick.Dialogs`:
  - `ColorDialog`: `color` → `selectedColor`; `showAlphaChannel: true` →
    `options: ColorDialog.ShowAlphaChannel`.
  - `FileDialog`: `fileUrl(s)` → `selectedFile(s)`; `folder` → `currentFolder`;
    `selectExisting`/`selectFolder` → `fileMode`.
- `org.kde.kquickcontrols` (`KQuickControls.ColorButton`, `KeySequenceItem`)
  sigue existiendo en Plasma 6. Sólo quita la versión del import.

### H. Páginas de configuración
- `contents/config/config.qml`: `import org.kde.plasma.configuration` (sin versión).
- La raíz de cada página `config*.qml` pasa a ser `KCM.SimpleKCM`
  (`import org.kde.kcmutils as KCM`), con el `Kirigami.FormLayout` **dentro**.
  Las propiedades `cfg_*` (y sus `alias`) **se quedan en la raíz**.
- Plasma 6 también asigna `cfg_<clave>Default`. Si no existe, sólo se emite un
  aviso inofensivo; puedes silenciarlo declarando `property var cfg_<clave>Default`.
- `contents/config/main.xml` no cambia.

### I. Scripts y documentación
- `kpackagetool5` → `kpackagetool6`.
- `kquitapp5 plasmashell && kstart5 plasmashell` → `systemctl --user restart plasma-plasmashell`.
- Actualiza README/documentación: versión de Plasma, `metadata.json`, comandos.

## Paso 3 — Verificación (no hay Plasma en tu contenedor)

No des el port por bueno sin verificarlo. Haz al menos esto:

1. **Lint con Qt 6**:
   ```bash
   python3 -m venv .venv && .venv/bin/pip install -q PySide6-Essentials
   LINT=$(ls .venv/lib/python3*/site-packages/PySide6/qmllint)
   $LINT $(find . -name '*.qml' -not -path './.venv/*') 2>&1 | grep -E '^(Warning|Error)' \
     | sed -E 's/.*\[([a-z-]+)\]$/\1/' | sort | uniq -c
   ```
   Las categorías `import`, `unresolved-type` y `unqualified` son esperables,
   porque los módulos KDE no están instalados. **Cualquier otra categoría**
   (`missing-property`, `syntax`, `type`, …) es un error real: corrígelo.
2. **Render offscreen con módulos KDE simulados.** El repo
   `LSPaninka/kde-claude-token` (rama `claude/plasma6-port`,
   carpeta `tools/qml-harness/`) tiene un arnés de ejemplo. Si tienes acceso,
   cópialo y adáptalo. Si no, construye uno equivalente:
   - Módulos QML falsos con `qmldir` en un directorio añadido con
     `engine.addImportPath()`: `PlasmoidItem` (Item con
     `property Component compactRepresentation/fullRepresentation`,
     `expanded`…); singleton `Plasmoid` con `configuration` generada desde
     los valores por defecto de `main.xml` y `formFactor`; los `Kirigami`
     `Theme`/`Units` como singletons; `Kirigami.Icon` como un rectángulo;
     `Plasma5Support.DataSource` que devuelve JSON simulado vía `Qt.callLater`.
   - `i18n()`: pon un *context object* de Python con slots `i18n(str[, a, b])`.
   - Instancia el `main.qml` real, crea `compactRepresentation` dentro de un
     `RowLayout` de 44 px (simula el panel) y `fullRepresentation` en un
     rectángulo; captura con `QQuickWindow.grabWindow()` y **mira las imágenes**.
   - Problemas conocidos: hace falta `sudo apt install libegl1 libgl1
     libxkbcommon0 libfontconfig1`; usa `QT_QPA_PLATFORM=offscreen` y
     `QT_QUICK_BACKEND=software`; importa `PySide6.QtQuick` en Python o
     `grabWindow` no existirá; en QML no se pueden declarar propiedades que
     empiecen por mayúscula, así que simula `PlasmaCore.Types.Vertical` con un
     `enum`; `Kirigami.FormData` es adjunta en C++ y no se puede simular, así
     que las páginas de configuración sólo se verifican con `qmllint`.
   - Captura todos los mensajes con `qInstallMessageHandler`. El objetivo es
     **cero `WARNING:`** provenientes del código del plasmoide.

## Paso 4 — Entrega

Haz commit y push de la rama nueva y termina con un resumen que incluya:
- Qué cambiaste, por archivo o por tipo de cambio.
- Cómo lo verificaste y con qué resultado (y las capturas, si hiciste render).
- Qué **no** pudiste verificar.
- Los comandos para que yo lo pruebe en mi equipo:
  ```bash
  kpackagetool6 -t Plasma/Applet -u <carpeta>/package   # o -i si no estaba instalado
  plasmoidviewer -a <carpeta>/package                   # paquete plasma-sdk, prueba aislada
  systemctl --user restart plasma-plasmashell
  journalctl --user -f | grep -iE "qml|plasma"          # errores en vivo
  ```

<!-- ========================== HASTA AQUÍ ========================== -->
