# Plasmoides para KDE Plasma 5.27

Colección de plasmoides (gadgets de escritorio/panel) para
**Kubuntu 24.04 / KDE Plasma 5.27 / Qt 5.15**, sin librerías externas.

| Carpeta | Plasmoide | Descripción |
|---|---|---|
| [`claude-usage/`](claude-usage/) | **Uso de Claude** | Uso de Claude Pro Individual: límite de 5 h y semanal, con anillos/barras, horas de reinicio y tiempo restante. |
| [`codex-usage/`](codex-usage/) | **Uso de Codex** | Uso semanal de Codex (ChatGPT), con la misma interfaz adaptada a un único límite. |
| [`separator/`](separator/) | **Separador de línea** | Línea separadora configurable (color, patrón, grosor, longitud, transparencia, orientación). |

Cada carpeta incluye su propio `install.sh` y `README.md` con los detalles.

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

Requisitos comunes: KDE Plasma 5.27, `kpackagetool5` (paquetes de desarrollo de
Plasma) y, para los de uso, `curl` (`jq` es opcional).

## Licencia

MIT. Ver [LICENSE](LICENSE).
