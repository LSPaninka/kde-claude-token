#!/usr/bin/env bash
#
# Verifica los plasmoides SIN Plasma: lint con qmllint de Qt 6 y render
# offscreen de las representaciones reales usando módulos KDE simulados.
# Útil en CI o en una máquina/contenedor sin escritorio KDE.
#
# Uso:  tools/qml-harness/check.sh          -> capturas en tools/qml-harness/out/
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/out"; mkdir -p "$OUT"

if [[ ! -x "$HERE/.venv/bin/python" ]]; then
    python3 -m venv "$HERE/.venv"
    "$HERE/.venv/bin/pip" install -q PySide6-Essentials
fi
PY="$HERE/.venv/bin/python"
LINT="$(ls "$HERE"/.venv/lib/python3*/site-packages/PySide6/qmllint)"

echo "== qmllint (sólo cuentan las categorías que NO sean import/unresolved-type/unqualified)"
"$LINT" $(find "$REPO"/{claude-usage,codex-usage,separator} -name '*.qml') 2>&1 \
  | grep -E '^(Warning|Error)' | sed -E 's/.*\[([a-z-]+)\]$/\1/' | sort | uniq -c | sort -rn

export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
run() { echo "== render $*"; "$PY" "$HERE/run.py" "$@" | grep -vE '^(debug|harness: connectSource)'; }
run "$REPO/claude-usage/package" usage            "$OUT/claude.png"
run "$REPO/claude-usage/package" usage            "$OUT/claude-rings.png" displayMode=rings
run "$REPO/codex-usage/package"  usage            "$OUT/codex.png"
run "$REPO/codex-usage/package"  codex-notstarted "$OUT/codex-notstarted.png"
run "$REPO/separator/package"    separator        "$OUT/separator-solid.png"
run "$REPO/separator/package"    separator        "$OUT/separator-dashed.png" pattern=dashed thickness=3 lineColor=#ff3daee9
run "$REPO/separator/package"    separator        "$OUT/separator-dotted.png" pattern=dotted thickness=4 gapLength=3 lineColor=#ffffd54f opacityPercent=70
echo "Capturas en $OUT. Cualquier línea 'WARNING:' arriba que no venga del arnés es un fallo real."
