# Plasmoides para KDE Plasma 6

Colección de plasmoides (gadgets de escritorio/panel) para
**Kubuntu 26.04 / KDE Plasma 6 (probado con 6.6) / Qt 6**, sin librerías externas.

> **Ramas:** esta rama (`claude/plasma6-port`) es la versión para **Plasma 6**.
> La versión para **Plasma 5.27 / Qt 5.15** sigue en
> `claude/plasmoide-claude-pro-usage-jno0v4`.
>
> **Si venías de Plasma 5:** basta con volver a ejecutar `./install.sh` en cada
> carpeta. Los IDs de los plasmoides no cambiaron, así que se actualizan en su
> sitio y conservan su configuración. Si alguno sigue mostrando el aviso
> «no es compatible con Plasma 6», quítalo del panel, ejecuta
> `systemctl --user restart plasma-plasmashell` y vuelve a añadirlo.

| Carpeta | Plasmoide | Descripción |
|---|---|---|
| [`claude-usage/`](claude-usage/) | **Uso de Claude** | Uso de Claude Pro Individual: límite de 5 h y semanal, con anillos/barras, horas de reinicio y tiempo restante. |
| [`codex-usage/`](codex-usage/) | **Uso de Codex** | Uso de Codex (ChatGPT): límite de 5 h y semanal, más un icono de reinicios disponibles. |
| [`separator/`](separator/) | **Separador de línea** | Línea separadora configurable (color, patrón, grosor, longitud, transparencia, orientación). |

Cada carpeta incluye su propio `install.sh` y `README.md` con los detalles.

## Verificar sin Plasma

[`tools/qml-harness/`](tools/qml-harness/) hace lint con Qt 6 y renderiza los
plasmoides offscreen con módulos KDE simulados: `tools/qml-harness/check.sh`.

## Portar otros plasmoides a Plasma 6

📄 **[`PROMPT.md`](PROMPT.md)** — prompt listo para pegar en una sesión nueva
(Sonnet) que porta un plasmoide de Plasma 5 a Plasma 6 siguiendo los mismos
pasos usados aquí.

## Portar a otros sistemas

📄 **[`SPEC.md`](SPEC.md)** — especificación técnica completa e independiente del
lenguaje: APIs, modelo de datos, reglas de formato, algoritmos de dibujo,
configuración, comportamientos y una guía de portabilidad a macOS, Windows y
GNOME/GTK. Pensado para reimplementar los tres widgets sin leer el código QML.

## Instalación rápida

```bash
# Cada plasmoide se instala por separado:
cd claude-usage && ./install.sh   # Uso de Claude
cd ../codex-usage && ./install.sh  # Uso de Codex
cd ../separator   && ./install.sh  # Separador de línea
```

Después: clic derecho en el escritorio o el panel → **«Añadir elementos
gráficos»** → busca el plasmoide por su nombre.

Requisitos comunes: KDE Plasma 6, `kpackagetool6` (paquetes de desarrollo de
Plasma) y, para los de uso, `curl` (`jq` es opcional).

## Licencia

MIT. Ver [LICENSE](LICENSE).
