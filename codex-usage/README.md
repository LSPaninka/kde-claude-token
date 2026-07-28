# Uso de Codex — Plasmoide para KDE

Plasmoide (gadget de escritorio) para **Kubuntu 24.04 / KDE Plasma 5.27 / Qt 5.15**
que muestra el porcentaje de uso **semanal** de **Codex** (a través de la cuenta
de ChatGPT). Comparte la misma interfaz que el plasmoide de Claude (anillos,
barras, etiquetas, comportamientos y configuración), adaptada a un único límite.

No usa librerías externas: solo QML/Qt Quick y las herramientas ya presentes en
el sistema (`curl`, y opcionalmente `jq`).

---

## Características

- **En el panel (modo minimalista):** un anillo con el porcentaje y, a su lado,
  la hora de reinicio semanal en formato `ddd hh:mm` (día en español, p. ej.
  `dom 08:00`; `-` si el límite no está establecido). **Clic izquierdo** abre la
  vista completa; **clic central** actualiza al instante. Tamaño configurable
  (**escala 50 %–100 %**).
- **Vista completa** con dos modos conmutables:
  - **Barra (completo):** una barra horizontal con el porcentaje, la hora de
    reinicio y el tiempo restante.
  - **Anillo:** un anillo con el porcentaje en el centro y, debajo, la hora de
    reinicio.
- **Botón de actualización** manual y **consulta periódica** configurable (por
  defecto **2 minutos**).
- **Colores configurables** (barra, anillo, fondos, etiquetas y porcentaje),
  grosor del anillo y color del tema o personalizado.

---

## Cómo obtiene los datos

Lee las credenciales de Codex y consulta la API de uso de ChatGPT. Equivale a:

```bash
AUTH_FILE="${CODEX_HOME:-$HOME/.codex}/auth.json"
ACCESS_TOKEN="$(jq -r '.tokens.access_token' "$AUTH_FILE")"
ACCOUNT_ID="$(jq -r '.tokens.account_id // .account_id' "$AUTH_FILE")"

curl -s https://chatgpt.com/backend-api/wham/usage \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "ChatGPT-Account-ID: $ACCOUNT_ID" \
  -H "Accept: application/json"
```

De la respuesta se usan `rate_limit.primary_window.used_percent` (porcentaje) y
`rate_limit.primary_window.reset_at` (marca de tiempo Unix del reinicio). El
`plan_type` se muestra en el encabezado de la vista completa.

Si `jq` no está disponible, el token y el `account_id` se extraen con `sed`.

> El token sólo se envía a `chatgpt.com`, igual que el `curl` de arriba.

### Requisitos

- `curl` (habitualmente ya instalado); `jq` opcional.
- Tener Codex autenticado mediante ChatGPT, de modo que exista
  `~/.codex/auth.json` con `tokens.access_token` y `tokens.account_id`.

---

## Instalación

```bash
cd codex-usage
./install.sh
```

Luego: clic derecho en el escritorio → **«Añadir elementos gráficos»** →
**«Uso de Codex»**. Para **actualizar** vuelve a ejecutar `./install.sh`; para
**desinstalar**: `./install.sh --remove`.

---

## Configuración

Clic derecho sobre el plasmoide → **«Configurar Uso de Codex…»**.

### Pestaña «General»

| Opción | Descripción | Por defecto |
|---|---|---|
| **Consultar cada** | Intervalo de consulta a la API (mín. 15 s). | `2 min` |
| **Modo de visualización** | Vista completa: `Barra` o `Anillo`. | Barra |
| **Mostrar el tiempo restante** | En modo barra, añade «faltan …». | Activado |
| **Escala del anillo (panel)** | Tamaño del anillo en el panel (50 %–100 %). | 100 % |
| **Titilar en errores** | Tras 2 errores seguidos, el fondo del anillo titila en rojo oscuro. | Activado |
| **Archivo de credenciales** | Ruta al `auth.json`. Vacío = `${CODEX_HOME:-~/.codex}/auth.json`. | (vacío) |

### Pestaña «Colores»

| Opción | Descripción |
|---|---|
| **Barra** | Color de relleno de la barra. |
| **Fondo de barra** | Color de la pista de la barra. |
| **Anillo** | Color del arco del anillo. |
| **Fondo de anillo** | Color de la pista del anillo. |
| **Grosor del anillo** | Grosor del trazo (2–40 px). |
| **Usar el color del tema** | Etiquetas y porcentajes con el color del tema de Plasma. |
| **Color de etiquetas** | Color de los textos (si no se usa el del tema). |
| **Color del porcentaje** | Color del número de porcentaje (si no se usa el del tema). |

Los colores se guardan como `#AARRGGBB` (con canal alfa).

---

## Licencia

MIT. Ver [LICENSE](../LICENSE).
