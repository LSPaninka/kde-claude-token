#!/usr/bin/env bash
#
# Instala (o actualiza) el plasmoide "Uso de Codex" en el usuario actual.
#
# Uso:
#   ./install.sh            # instala o actualiza
#   ./install.sh --remove   # desinstala
#
set -euo pipefail

PLUGIN_ID="io.peperina.codexusage"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/package"

if ! command -v kpackagetool5 >/dev/null 2>&1; then
    echo "Error: no se encontró 'kpackagetool5'. Instala los paquetes de desarrollo de Plasma." >&2
    exit 1
fi

if [[ "${1:-}" == "--remove" ]]; then
    echo "Desinstalando $PLUGIN_ID ..."
    kpackagetool5 --type Plasma/Applet --remove "$PLUGIN_ID"
    echo "Listo. Reinicia plasmashell si el applet sigue visible."
    exit 0
fi

if kpackagetool5 --type Plasma/Applet --list 2>/dev/null | grep -q "^${PLUGIN_ID}$"; then
    echo "Actualizando $PLUGIN_ID ..."
    kpackagetool5 --type Plasma/Applet --upgrade "$PKG_DIR"
else
    echo "Instalando $PLUGIN_ID ..."
    kpackagetool5 --type Plasma/Applet --install "$PKG_DIR"
fi

echo
echo "Instalado correctamente."
echo "Añádelo desde: clic derecho en el escritorio -> «Añadir elementos gráficos» -> «Uso de Codex»."
echo "Para recargar cambios durante el desarrollo puede ayudar: kquitapp5 plasmashell && kstart5 plasmashell"
