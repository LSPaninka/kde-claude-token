# Uso de Claude — Plasmoide para KDE

Plasmoide (gadget de escritorio) para **Kubuntu 24.04 / KDE Plasma 5.27 / Qt 5.15**
que muestra el porcentaje de uso actual de **Claude Pro Individual**: el límite
de **5 horas** y el límite **semanal**, con la hora de reinicio y el tiempo
restante de cada uno.

No usa librerías externas: solo QML/Qt Quick y las herramientas de línea de
comandos ya presentes en el sistema (`curl`, y opcionalmente `jq`).

![modos](docs/preview.png)

---

## Características

- **En el panel (modo minimalista):** al colocar el plasmoide en un panel
  muestra dos anillos compactos con el porcentaje y, junto a cada uno, la hora
  de reinicio (5h → `hh:mm`; 7d → `ddd hh:mm`; `-` si el límite no está
  establecido). **Clic izquierdo** abre la vista completa; **clic central**
  actualiza los datos al instante sin abrir el panel. El tamaño de los anillos
  es configurable (**escala 50 %–100 %** del grosor del panel; al 100 % ocupan
  prácticamente todo el grosor, como los iconos vecinos).
- **En el escritorio / ventana emergente (vista completa)**, con dos modos
  conmutables en la configuración:
  - **Barras (completo):** dos barras horizontales (5h y semanal) con el
    porcentaje, la hora de reinicio y el tiempo restante.
  - **Anillos:** dos anillos con el porcentaje en el centro y, debajo, la hora
    de reinicio.
    - Anillo 5h → `hh:mm`
    - Anillo 7d → `ddd hh:mm` (donde `ddd` son las tres primeras letras del día
      de la semana en español: `lun, mar, mié, jue, vie, sáb, dom`).
- **Botón de actualización** manual.
- **Consulta periódica** configurable (por defecto **2 minutos**).
- **Todo configurable:** colores de barras, anillos y textos, grosor del anillo,
  color del tema o personalizado, ruta del archivo de credenciales.

---

## Cómo obtiene los datos

El plasmoide lee el token OAuth guardado en tu instalación de Claude Code y
consulta la API de uso de Anthropic. Equivale a este `curl`:

```bash
TOKEN=$(jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json)

curl -s https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "User-Agent: claude-code/2.1.211" \
  -H "Content-Type: application/json"
```

Internamente se ejecuta un comando de shell (motor `executable` del DataEngine
de Plasma) que:

1. Extrae el token de `~/.claude/.credentials.json` con `jq`; si `jq` no está
   disponible, cae automáticamente a `sed`.
2. Llama a `https://api.anthropic.com/api/oauth/usage` con los encabezados de
   arriba.
3. La respuesta JSON se interpreta en QML (`JSON.parse`).

Se usan los campos `five_hour.utilization` / `five_hour.resets_at` y
`seven_day.utilization` / `seven_day.resets_at` de la respuesta.

> El token **nunca sale** de tu equipo salvo hacia `api.anthropic.com`, igual
> que el `curl` de arriba. No se registra ni se guarda en ningún otro sitio.

### Requisitos

- `curl` (habitualmente ya instalado).
- `jq` es **opcional** (mejora la lectura del token). Instálalo con
  `sudo apt install jq` si lo deseas.
- Tener la sesión de Claude Code iniciada, de modo que exista
  `~/.claude/.credentials.json`.

---

## Instalación

```bash
git clone <este-repositorio>
cd kde-claude-token
./install.sh
```

Luego: clic derecho en el escritorio → **«Añadir elementos gráficos»** →
busca **«Uso de Claude»** y arrástralo al escritorio.

Para **actualizar** tras cambios vuelve a ejecutar `./install.sh`.
Para **desinstalar**: `./install.sh --remove`.

Instalación manual alternativa (equivalente):

```bash
kpackagetool5 --type Plasma/Applet --install package
# actualizar:
kpackagetool5 --type Plasma/Applet --upgrade package
# eliminar:
kpackagetool5 --type Plasma/Applet --remove io.peperina.claudeusage
```

Si el applet no refleja los cambios durante el desarrollo:

```bash
kquitapp5 plasmashell && kstart5 plasmashell
```

---

## Configuración

Clic derecho sobre el plasmoide → **«Configurar Uso de Claude…»**.

### Pestaña «General»

| Opción | Descripción | Por defecto |
|---|---|---|
| **Consultar cada** | Intervalo de consulta a la API (mín. 15 s). Acepta segundos o minutos. | `2 min` |
| **Modo de visualización** | Vista completa: `Barras` o `Anillos`. | Barras |
| **Mostrar el tiempo restante** | En modo barras, añade «faltan …» junto a la hora de reinicio. | Activado |
| **Escala de los anillos (panel)** | Tamaño de los anillos cuando el plasmoide está en un panel (50 %–100 %). | 100 % |
| **Archivo de credenciales** | Ruta al `.credentials.json`. Vacío = `~/.claude/.credentials.json`. | (vacío) |

### Pestaña «Colores»

| Opción | Descripción |
|---|---|
| **Barra 5h** | Color de relleno de la barra del límite de 5 horas. |
| **Barra semanal** | Color de relleno de la barra del límite semanal. |
| **Fondo de barra** | Color de la pista (fondo) de las barras. |
| **Anillo 5h** | Color del arco del anillo de 5 horas. |
| **Anillo semanal** | Color del arco del anillo semanal. |
| **Fondo de anillo** | Color de la pista (fondo) de los anillos. |
| **Grosor del anillo** | Grosor del trazo del anillo (2–40 px). |
| **Usar el color del tema** | Si está activo, las etiquetas y porcentajes usan el color de texto del tema de Plasma. |
| **Color de etiquetas** | Color de los textos (títulos, horas). Solo si no se usa el color del tema. |
| **Color del porcentaje** | Color del número de porcentaje. Solo si no se usa el color del tema. |

El selector de color admite **canal alfa** (transparencia). Los colores se
guardan como cadenas hexadecimales `#AARRGGBB`.

---

## Estructura del proyecto

```
package/
├── metadata.desktop              Metadatos del applet (Plasma 5)
└── contents/
    ├── config/
    │   ├── main.xml              Definición de las claves de configuración (KConfigXT)
    │   └── config.qml           Categorías de la ventana de configuración
    └── ui/
        ├── main.qml             Lógica principal: descarga de datos, temporizadores, layout
        ├── BarsView.qml         Vista de barras (modo completo)
        ├── RingsView.qml        Vista de anillos (modo minimalista)
        ├── UsageBar.qml         Componente de barra horizontal reutilizable
        ├── RingChart.qml        Componente de anillo (donut) dibujado con Canvas
        ├── ColorButton.qml      Botón selector de color para la configuración
        ├── configGeneral.qml    Página de configuración «General»
        ├── configAppearance.qml Página de configuración «Colores»
        └── lib/
            └── format.js        Utilidades de formato de fecha/hora y color
```

---

## Solución de problemas

- **«Sin respuesta»**: comprueba que `curl` está instalado y que
  `~/.claude/.credentials.json` existe y contiene `claudeAiOauth.accessToken`.
- **Error de la API / 401**: el token puede haber caducado. Vuelve a iniciar
  sesión en Claude Code para regenerar las credenciales.
- **El applet aparece vacío**: pulsa el botón **Actualizar**; revisa los
  registros con `journalctl --user -f | grep -i plasma` mientras actualizas.

---

## Licencia

MIT. Ver [LICENSE](../LICENSE).
