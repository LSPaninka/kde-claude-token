# qml-harness — verificar los plasmoides sin Plasma

Permite comprobar los plasmoides en una máquina **sin KDE Plasma** (un contenedor,
CI, otra distro). Hace dos cosas:

1. **Lint** de todos los `.qml` con el `qmllint` de Qt 6 (vía PySide6).
2. **Render offscreen** del `main.qml` real: crea la representación compacta
   (panel) y la completa, les inyecta respuestas de API simuladas y guarda
   capturas de una línea de tiempo. La línea de tiempo cubre: éxito (destello
   verde), fallo (destello rojo), 2 fallos (alarma) y recuperación. También
   prueba el `ColorDialog` de Qt 6 de `ColorButton`.

```bash
tools/qml-harness/check.sh      # crea .venv la primera vez; capturas en out/
```

Requisitos del sistema: `python3-venv` y las librerías GL/EGL
(`sudo apt install libegl1 libgl1 libxkbcommon0 libfontconfig1`).

## Cómo funciona

`run.py` genera, en `stubs_run/`, módulos QML falsos con lo mínimo que usan
estos plasmoides:

| Módulo real | Simulación |
|---|---|
| `org.kde.plasma.plasmoid` | `PlasmoidItem` (Item con `compactRepresentation`, `fullRepresentation`, `expanded`…) y un singleton `Plasmoid` cuya `configuration` se genera con los **valores por defecto del `main.xml`** del paquete (+ overrides `clave=valor`). |
| `org.kde.plasma.core` | `Types` con el enum `FormFactor`. |
| `org.kde.plasma.plasma5support` | `DataSource` que, en vez de ejecutar `curl`, devuelve JSON de `fixtures/` según la URL del comando. |
| `org.kde.plasma.components` | `Label`, `ToolButton`, `BusyIndicator` (envuelven QtQuick.Controls). |
| `org.kde.kirigami` | `Theme`, `Units` (singletons) e `Icon` (una caja con la inicial del icono pedido). |

`i18n()` lo aporta un *context object* de Python, igual que `KLocalizedContext`
en Plasma.

**Limitaciones:** no prueba las páginas de configuración, porque
`Kirigami.FormData` es una propiedad adjunta en C++ y no se puede simular en QML
puro. Esas páginas sólo pasan por `qmllint`. Tampoco hace peticiones reales a
las APIs.

Escenarios: `usage`, `codex-notstarted`, `separator`. Ejemplo manual:

```bash
.venv/bin/python run.py ../../codex-usage/package usage out/x.png displayMode=rings
```
