#!/usr/bin/env bash
#
# Compila la app en release y la deja corriendo en segundo plano, desacoplada
# de la terminal (puedes cerrar la terminal y sigue viva en la barra de menús).
#
#   ./run.sh          build + (re)lanzar en segundo plano
#   ./run.sh stop     detener la instancia en ejecución
#   ./run.sh restart  = stop + build + lanzar
#   ./run.sh log      seguir el log en vivo (Ctrl-C para salir)
#
set -euo pipefail

# Directorio de este script (para poder invocarlo desde cualquier sitio).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

APP="ClaudeCodexUsage"
BIN=".build/release/$APP"
LOG="$DIR/$APP.log"
PIDFILE="$DIR/.$APP.pid"

stop() {
    # Por PID guardado…
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        kill "$(cat "$PIDFILE")" 2>/dev/null || true
    fi
    # …y por si quedó alguna instancia suelta.
    pkill -f "$BIN" 2>/dev/null || true
    rm -f "$PIDFILE"
}

case "${1:-start}" in
    stop)
        echo "Deteniendo $APP…"
        stop
        echo "Detenido."
        ;;

    log)
        touch "$LOG"
        tail -f "$LOG"
        ;;

    start|restart|"")
        echo "Deteniendo instancia previa (si la hay)…"
        stop

        echo "Compilando en release…"
        swift build -c release

        echo "Lanzando en segundo plano…"
        # nohup + & desacopla del terminal; la salida va al log.
        nohup "$BIN" >"$LOG" 2>&1 &
        echo $! >"$PIDFILE"
        disown 2>/dev/null || true

        echo "$APP corriendo (PID $(cat "$PIDFILE")). Mira la barra de menús."
        echo "Log:   $LOG"
        echo "Parar: ./run.sh stop"
        ;;

    *)
        echo "Uso: ./run.sh [start|stop|restart|log]" >&2
        exit 1
        ;;
esac
