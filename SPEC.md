# Especificación técnica y guía de portabilidad

Este documento describe **de forma independiente del lenguaje y del sistema
operativo** los tres plasmoides de este repositorio, para que puedan
reimplementarse en otras plataformas (macOS, Windows, GNOME/GTK, Electron,
Flutter, etc.) sin necesidad de leer el código QML original.

Los tres componentes son:

| # | Nombre | Función |
|---|--------|---------|
| 1 | **Uso de Claude** | Muestra el uso de Claude Pro Individual: límite de 5 h y límite semanal. |
| 2 | **Uso de Codex** | Muestra el uso semanal de Codex (ChatGPT). Misma interfaz, un solo límite. |
| 3 | **Separador de línea** | Dibuja una línea separadora configurable. Sin red ni datos. |

La implementación de referencia está hecha en **QML / Qt Quick 5.15** para
**KDE Plasma 5.27**, sin librerías externas.

---

## Índice

1. [Arquitectura general](#1-arquitectura-general)
2. [Fuentes de datos y APIs](#2-fuentes-de-datos-y-apis)
3. [Modelo de datos y valores derivados](#3-modelo-de-datos-y-valores-derivados)
4. [Reglas de formato](#4-reglas-de-formato)
5. [Referencia de configuración](#5-referencia-de-configuración)
6. [Especificación visual](#6-especificación-visual)
7. [Comportamientos e interacción](#7-comportamientos-e-interacción)
8. [Ciclo de actualización (máquina de estados)](#8-ciclo-de-actualización-máquina-de-estados)
9. [Manejo de errores](#9-manejo-de-errores)
10. [Localización](#10-localización)
11. [Seguridad y privacidad](#11-seguridad-y-privacidad)
12. [Guía de portabilidad por plataforma](#12-guía-de-portabilidad-por-plataforma)
13. [Ejemplos de referencia (peticiones y respuestas)](#13-ejemplos-de-referencia)

---

## 1. Arquitectura general

Cada widget tiene **dos "representaciones"**:

- **Compacta (panel):** versión minimalista pensada para una barra/panel/menubar.
- **Completa (escritorio o ventana emergente):** versión detallada.

Los dos widgets de uso (Claude, Codex) comparten estos subsistemas:

```
┌──────────────────────────────────────────────────────────┐
│  Temporizador de sondeo (intervalo configurable)          │
│      └─> Fetcher ──> API HTTPS ──> JSON                    │
│                          └─> Parser ──> Modelo de datos    │
│                                            └─> Vistas      │
│  Temporizador de reloj (1 s) ──> recalcula "tiempo restante"│
└──────────────────────────────────────────────────────────┘
```

El separador **no** tiene red ni temporizadores: solo dibuja una figura a partir
de su configuración.

Componentes reutilizables (en la referencia, archivos QML; en un port, clases o
componentes equivalentes):

- **RingChart** — anillo/donut con porcentaje en el centro.
- **UsageBar** — barra de progreso horizontal.
- **ColorButton** — selector de color para la configuración.
- **format** — utilidades puras de formato (fechas, tiempo, color).

---

## 2. Fuentes de datos y APIs

Ambos widgets de uso obtienen los datos leyendo un **token de sesión local** y
haciendo **una petición HTTPS GET**. No hay OAuth interactivo: el token ya existe
en el disco porque el usuario inició sesión con la CLI correspondiente.

### 2.1 API de Claude

- **Método y URL:** `GET https://api.anthropic.com/api/oauth/usage`
- **Cabeceras:**
  | Cabecera | Valor |
  |---|---|
  | `Authorization` | `Bearer <accessToken>` |
  | `anthropic-beta` | `oauth-2025-04-20` |
  | `User-Agent` | `claude-code/2.1.211` |
  | `Content-Type` | `application/json` |
- **Token:** archivo JSON `~/.claude/.credentials.json`, campo
  `claudeAiOauth.accessToken`.
- **Campos usados de la respuesta:**
  - `five_hour.utilization` (número, 0–100) → porcentaje del límite de 5 h.
  - `five_hour.resets_at` (cadena ISO 8601 con zona) → instante de reinicio.
  - `seven_day.utilization` (número, 0–100) → porcentaje del límite semanal.
  - `seven_day.resets_at` (ISO 8601) → instante de reinicio semanal.

> Nota: `User-Agent` es significativo. Algunos clientes HTTP de navegador no
> permiten fijarlo; usa un cliente HTTP nativo que sí lo permita.

### 2.2 API de Codex (ChatGPT)

- **Método y URL:** `GET https://chatgpt.com/backend-api/wham/usage`
- **Cabeceras:**
  | Cabecera | Valor |
  |---|---|
  | `Authorization` | `Bearer <access_token>` |
  | `ChatGPT-Account-ID` | `<account_id>` |
  | `Accept` | `application/json` |
- **Credenciales:** archivo JSON `${CODEX_HOME:-~/.codex}/auth.json`:
  - `tokens.access_token` (obligatorio).
  - `tokens.account_id` — y como respaldo `account_id` en la raíz (versiones
    antiguas).
  - `auth_mode` debe ser `"chatgpt"` (si no, la sesión no es válida para esta API).
- **Campos usados de la respuesta:**
  - `plan_type` (cadena, p. ej. `"plus"`) → se muestra en el encabezado.
  - `rate_limit.primary_window.used_percent` (número, 0–100) → porcentaje.
  - `rate_limit.primary_window.reset_at` (**entero, segundos Unix**) → reinicio.
  - (opcionales/informativos) `rate_limit.allowed`, `rate_limit.limit_reached`,
    `rate_limit.primary_window.limit_window_seconds` (604800 = 7 días).

> Codex solo expone **un** límite (ventana semanal). Si en el futuro apareciera
> una ventana adicional (`secondary_window`), se trataría como el segundo límite
> (equivalente al de 5 h de Claude).

### 2.3 Manejo de credenciales

Pseudocódigo de lectura del token (idéntico patrón en ambos, distintos campos):

```
función leerToken(rutaArchivo, ...camposJSON):
    texto = leerArchivoDeTexto(rutaArchivo)      # UTF-8
    obj   = parsearJSON(texto)
    devolver navegar(obj, camposJSON)            # p. ej. obj.claudeAiOauth.accessToken
```

Rutas por defecto (expandir `~` y variables de entorno):

- Claude: `~/.claude/.credentials.json`
- Codex:  `${CODEX_HOME:-~/.codex}/auth.json`

Ambas deben poder **sobrescribirse** por configuración (ver §5).

### 2.4 Obtención nativa vs. shell

La referencia QML no tiene cliente HTTP con cabeceras arbitrarias cómodo, así que
ejecuta un comando de shell (`curl`) mediante el motor de ejecución de Plasma, con
respaldo a `sed` cuando `jq` no está disponible. **En un port nativo, no hagas
esto:** usa el cliente HTTP del lenguaje (URLSession, HttpClient, libsoup, fetch,
Dio…) y el parser JSON nativo, leyendo el archivo de credenciales directamente.

El contrato es el mismo: leer token del archivo → GET con las cabeceras → parsear
JSON → mapear al modelo de datos.

---

## 3. Modelo de datos y valores derivados

Modelo interno normalizado (común a ambos widgets):

```
Limite:
    utilization: número          # 0..100 (porcentaje usado)
    resetsAt:    instante | null # momento absoluto del reinicio

Uso:
    limites: lista<Limite>       # Claude: [5h, semanal]; Codex: [semanal]
    plan:    cadena | null       # solo Codex
    updatedAt: instante          # cuándo se obtuvo con éxito
```

Reglas de normalización:

- **utilization ausente/null → 0.**
- **resetsAt ausente/null/no parseable → null** (se mostrará como `-`, ver §4).
- Claude: `resets_at` es ISO 8601 → parsear como fecha con zona.
- Codex: `reset_at` son **segundos Unix** → `instante = epochSeconds * 1000`
  (milisegundos) o equivalente.

Valores derivados calculados en cada repintado:

- **porcentaje mostrado** = `round(utilization)`.
- **fracción de barra/anillo** = `clamp(utilization / 100, 0, 1)`.
- **tiempo restante** = `resetsAt - ahora` (recalculado cada segundo).

---

## 4. Reglas de formato

Funciones puras (sin estado). `two(n)` = entero con cero a la izquierda a 2 dígitos.

### 4.1 Hora de reinicio

- **Formato 5 h (y cualquier "hora corta"):** `HH:MM` en **hora local**.
  `fmtHM(fecha) = two(hora) + ":" + two(minuto)`.
- **Formato semanal:** `ddd HH:MM`, donde `ddd` son las **tres primeras letras
  del día de la semana en español**.
  `fmtDddHM(fecha) = DIAS[fecha.diaSemana] + " " + fmtHM(fecha)`.
- **Límite no establecido (`resetsAt == null`): mostrar `-`** (un guion medio).

Tabla de días (índice = día de la semana con **0 = domingo … 6 = sábado**, como
`Date.getDay()`):

```
DIAS = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
```

> Cuidado con la convención del día de la semana de cada plataforma. Si tu API de
> fechas usa 1 = lunes … 7 = domingo, reindexa para que domingo caiga en `dom`.

### 4.2 Tiempo restante

A partir de milisegundos restantes (`ms`):

```
fmtRemaining(ms):
    si ms es inválido o <= 0: devolver "0m"
    s = floor(ms / 1000)
    d = floor(s / 86400); s -= d*86400
    h = floor(s / 3600);  s -= h*3600
    m = floor(s / 60)
    si d > 0: devolver  d + "d " + h + "h"
    si h > 0: devolver  h + "h " + m + "m"
    devolver m + "m"
```

Ejemplos: `90061000 ms → "1d 1h"`, `9000000 ms → "2h 30m"`, `480000 ms → "8m"`.

### 4.3 Color hexadecimal

Los colores se serializan como cadena `#AARRGGBB` (alfa primero, 8 dígitos hex).

```
colorToHex(c):  # componentes 0..1
    h(x) = hex2(round(x*255))
    devolver "#" + h(c.a) + h(c.r) + h(c.g) + h(c.b)
```

Al leer, aceptar también `#RRGGBB` (alfa = FF).

---

## 5. Referencia de configuración

Todos los ajustes son persistentes por instancia del widget. Tipos: `Int`,
`Bool`, `String`, `Color` (guardado como `String` hex `#AARRGGBB`).

### 5.1 Uso de Claude

**General**

| Clave | Tipo | Def. | Rango | Descripción |
|---|---|---|---|---|
| `refreshInterval` | Int (s) | `120` | 15–86400 | Intervalo de sondeo. **Def. = 2 min.** |
| `credentialsPath` | String | `""` | — | Vacío = `~/.claude/.credentials.json`. |
| `displayMode` | String | `"bars"` | `bars`/`rings` | Vista completa: barras o anillos. |
| `showRemaining` | Bool | `true` | — | Añadir "faltan …" en modo barras. |
| `panelIconScale` | Int (%) | `100` | 50–100 | Tamaño de los anillos en el panel. |
| `errorBlink` | Bool | `true` | — | Titilar el fondo del anillo en rojo oscuro tras 2 errores seguidos. |

**Apariencia (colores `#AARRGGBB`)**

| Clave | Def. | Descripción |
|---|---|---|
| `bar5hColor` | `#ffcc785c` | Relleno barra 5 h. |
| `bar7dColor` | `#ff7c5cff` | Relleno barra semanal. |
| `barTrackColor` | `#40808080` | Fondo de las barras. |
| `ring5hColor` | `#ffcc785c` | Arco anillo 5 h. |
| `ring7dColor` | `#ff7c5cff` | Arco anillo semanal. |
| `ringTrackColor` | `#40808080` | Fondo de los anillos. |
| `ringThickness` | `12` | Grosor del trazo del anillo (2–40). |
| `labelColor` | `#ffffffff` | Color de etiquetas de texto. |
| `percentColor` | `#ffffffff` | Color del número de porcentaje. |
| `useThemeTextColor` | `true` (Bool) | Usar color de texto del tema en vez de los dos anteriores. |

### 5.2 Uso de Codex

**General:** idéntico a Claude, salvo:
- `credentialsPath` vacío = `${CODEX_HOME:-~/.codex}/auth.json`.

**Apariencia** (un solo límite → un solo color de acento):

| Clave | Def. | Descripción |
|---|---|---|
| `barColor` | `#ff10a37f` | Relleno de la barra. |
| `barTrackColor` | `#40808080` | Fondo de la barra. |
| `ringColor` | `#ff10a37f` | Arco del anillo. |
| `ringTrackColor` | `#40808080` | Fondo del anillo. |
| `ringThickness` | `12` | Grosor del anillo (2–40). |
| `labelColor` | `#ffffffff` | Color de etiquetas. |
| `percentColor` | `#ffffffff` | Color del porcentaje. |
| `useThemeTextColor` | `true` | Usar color del tema. |

### 5.3 Separador de línea

**Apariencia**

| Clave | Tipo | Def. | Rango | Descripción |
|---|---|---|---|---|
| `lineColor` | String | `#ffffffff` | — | Color de la línea. |
| `pattern` | String | `"solid"` | `solid`/`dashed`/`dotted` | Patrón del trazo. |
| `orientation` | String | `"auto"` | `auto`/`vertical`/`horizontal` | Ver §6.6. |
| `thickness` | Int (px) | `2` | 1–40 | Grosor de la línea. |
| `lengthPercent` | Int (%) | `80` | 5–100 | Longitud sobre el espacio disponible. |
| `opacityPercent` | Int (%) | `100` | 0–100 | Transparencia (multiplica el alfa del color). |
| `dashLength` | Int (px) | `6` | 1–40 | Trazo (solo dashed/dotted). |
| `gapLength` | Int (px) | `4` | 1–40 | Hueco (solo dashed/dotted). |

---

## 6. Especificación visual

### 6.1 Modelo de color

Color = RGBA. Serialización `#AARRGGBB`. El **fondo/pista** por defecto usa un gris
semitransparente (`#40808080`, alfa 25 %) para verse sobre temas claros y oscuros.
El color de texto por defecto sigue el tema del sistema.

### 6.2 RingChart (anillo/donut)

Parámetros: `value` (0–100), `ringColor`, `trackColor`, `textColor`, `thickness`,
`caption` (opcional, p. ej. "5h"/"7d"), tamaño `S = min(ancho, alto)`.

Algoritmo de dibujo (coordenadas con origen arriba-izquierda; ángulos en radianes):

```
cx = ancho/2 ; cy = alto/2
r  = S/2 - thickness/2 - 1              # radio del trazo
# 1) Pista completa
arco(cx, cy, r, 0, 2π)  con grosor=thickness, color=trackColor
# 2) Progreso
si value > 0:
    inicio = -π/2                        # arriba (12 en punto)
    fin    = inicio + 2π * (value/100)   # sentido horario
    arco(cx, cy, r, inicio, fin) con grosor=thickness, color=ringColor,
        extremo="redondo"
# 3) Texto central
dibujarTextoCentrado(round(value) + "%", color=textColor,
    tamaño=max(7, S*0.28), negrita)
si caption:
    dibujarTextoCentrado(caption, debajo, color=textColor, alfa=0.8,
        tamaño=max(6, S*0.14))
```

Notas de port: usa el `Canvas`/`Path`/`CAShapeLayer`/`Cairo` del entorno. El
extremo redondeado ("round cap") en el arco de progreso es intencional.

**Destello y alarma (solo panel).** Con `mezcla(a,b,t) = rgba(a.r+(b.r-a.r)·t, …)`,
el color efectivo se calcula por capas (base con alarma, destello encima):

```
arcoBase   = alarm ? mezcla(ringColor,  #ff1744, alarmProgress) : ringColor
fondoBase  = alarm ? mezcla(trackColor, #8b0000, alarmProgress) : trackColor
drawColor       = flashProgress>0 ? mezcla(arcoBase,  flashArcColor,   flashProgress) : arcoBase
trackDrawColor  = (flashProgress>0 && flashTrackEnabled)
                    ? mezcla(fondoBase, flashTrackColor, flashProgress) : fondoBase
```

- **Éxito:** `flashArcColor = #00e676`, `flashTrackColor = #006400`
  (`flashTrackEnabled = true`); `flashProgress` 0→1→0 (≈150 ms + ≈550 ms).
- **Fallo:** `flashArcColor = #ff1744`, `flashTrackEnabled = false`.
- **Alarma (2+ fallos):** `alarmProgress` en bucle infinito 0→1→0 (≈700 ms cada
  tramo, sinusoidal); tiñe fondo (rojo oscuro) y arco (rojo brillante) a la vez.

El texto no se toca. Los anillos de la vista completa no usan destello ni alarma.

### 6.3 UsageBar (barra horizontal)

Parámetros: `value`, `fillColor`, `trackColor`, `textColor`, `percentColor`,
`title`, `rightText`.

```
Columna:
    Fila:  [ title (izq, negrita) ...............  round(value)+"%" (der) ]
    Pista: rectángulo redondeado, alto=14, radio=alto/2, color=trackColor
           Relleno: mismo alto/radio, color=fillColor,
                    ancho = clamp(value/100,0,1) * anchoPista
                    (animar cambios de ancho ~400 ms, easing suave — opcional)
    rightText: texto pequeño (info de reinicio), alfa 0.8, elipsis a la derecha
```

### 6.4 Etiquetas y tipografía

- Números de porcentaje: **negrita**.
- Etiquetas de reinicio en el panel: negrita, tamaño ≈ `0.30 * tamañoAnillo`.
- Si `useThemeTextColor` = true, **todos** los textos usan el color de texto del
  tema; si es false, las etiquetas usan `labelColor` y los porcentajes
  `percentColor`.

### 6.5 Disposición: panel (compacta) vs. completa

**Widgets de uso — representación compacta (panel):**

- Claude: **dos** anillos; Codex: **un** anillo.
- Cada anillo va acompañado, **a su lado**, de la etiqueta de hora de reinicio:
  - 5 h → `HH:MM`
  - semanal → `ddd HH:MM`
  - `-` si el límite no está establecido.
- Tamaño del anillo = `grosorPanel * (panelIconScale/100)`. Al 100 % ocupa
  (casi) todo el grosor del panel, comparable a los iconos vecinos.
- En panel **horizontal** los pares se colocan en fila; en panel **vertical** se
  apilan. El grosor del anillo interno en el panel = `max(2, tamañoAnillo*0.15)`
  (independiente de `ringThickness`, que aplica a la vista completa).
- **Sin tooltip** (un tooltip emergente interfiere con el clic; ver §7).

**Widgets de uso — representación completa:**

```
Columna (márgenes pequeños):
    Encabezado (fila):
        [icono]  Título ("Uso de Claude" / "Uso de Codex — <plan>")
        [indicador de carga cuando aplica]  [botón Actualizar]
    Cuerpo: barras o anillos según displayMode
        Claude: dos elementos (5h, semanal)
        Codex:  un elemento (semanal), centrado
    Pie:
        si hay error:  "⚠ <mensaje>" en color de error
        si no:         "Actualizado HH:MM" (alineado a la derecha, tenue)
```

En la vista completa, cada anillo lleva **debajo** su etiqueta de reinicio
(mismo formato que en el panel); cada barra lleva su línea `rightText` con
"Reinicia <hora>" y, si `showRemaining`, "· faltan <tiempo>".

### 6.6 Separador (dibujo de la línea)

Parámetros efectivos:

```
colorEfectivo = rgba(base.r, base.g, base.b, base.a * opacityPercent/100)
vertical = ( orientation=="vertical" )  ||
           ( orientation=="auto" && panel NO es vertical )
```

En **auto**, la línea es **perpendicular** a la dirección del panel: vertical en
un panel horizontal, horizontal en un panel vertical (y vertical en el escritorio).

Dibujo:

```
si vertical:
    x   = round(ancho/2) + (thickness impar ? 0.5 : 0)   # nitidez de píxel
    len = alto * lengthPercent/100
    y0  = (alto - len)/2
    línea de (x, y0) a (x, y0+len)
si no:
    y   = round(alto/2) + (thickness impar ? 0.5 : 0)
    len = ancho * lengthPercent/100
    x0  = (ancho - len)/2
    línea de (x0, y) a (x0+len, y)

grosor de línea = thickness
patrón:
    solid  -> sin discontinuidad, extremo "butt"
    dashed -> discontinuidad [dashLength, gapLength], extremo "butt"
    dotted -> extremo "round", discontinuidad [1, gapLength + thickness]
```

El separador **se dibuja siempre en línea** (inline) en el panel; nunca se colapsa
a un icono con ventana emergente (equivalente al "Panel Spacer" nativo).

Dimensionado del applet: en el eje del grosor mide `thickness + relleno`; en el
otro eje se **estira** para llenar el panel. En el escritorio, tamaño por defecto
razonable (p. ej. 4 unidades de rejilla en el eje largo).

---

## 7. Comportamientos e interacción

Widgets de uso:

- **Sondeo periódico** cada `refreshInterval` segundos; **se dispara también al
  arrancar**.
- **Reloj interno** de 1 s: solo recalcula el "tiempo restante" mostrado; no hace
  red.
- **Botón Actualizar** en la vista completa: fuerza una obtención inmediata.
- **Panel (compacta):**
  - **Clic izquierdo** → abrir/cerrar la vista completa.
  - **Clic central** → actualizar de inmediato, sin abrir la vista.
- **Sin tooltip** en la representación de panel (bloqueaba el clic).
- **Destello de actualización (solo anillos de la vista de panel):** cada vez
  que termina una obtención de datos (por sondeo, botón o clic central), el
  anillo hace un breve *fade* y vuelve a su color original:
  - **Éxito → arco verde brillante** (`#00e676`) **y fondo verde oscuro**
    (`#006400`).
  - **Fallo → arco rojo brillante** (`#ff1744`); el fondo **no** se tiñe en el
    destello (de eso se encarga la alarma).

  Curva: `flashProgress` 0→1 en ~150 ms (ease-out) y 1→0 en ~550 ms (ease-in);
  arco y (si aplica) fondo se pintan mezclando su color base con el color de
  destello según `flashProgress` (ver §6.2). **No** afecta al texto, ni a los
  anillos de la vista completa, ni a las barras. Implementación: la lógica de
  obtención emite `usageUpdated(ok)`; la vista de panel llama a
  `flash(arcoVerde, fondoVerdeOscuro)` u `flash(arcoRojo, "")` según `ok`.
- **Alarma por errores consecutivos (solo anillos de la vista de panel):** se
  mantiene un contador `failStreak` (errores seguidos; 0 en cada éxito, +1 en
  cada fallo). Cuando `failStreak >= 2` **y** la opción `errorBlink` está activa
  (por defecto **sí**), cada anillo **titila sin parar** con un *fade* en bucle:
  el **fondo/pista** hacia **rojo oscuro** (`#8b0000`) y, sincronizado, el
  **arco de progreso** hacia **rojo brillante** (`#ff1744`), ambos con el mismo
  `alarmProgress` 0→1→0 (~700 ms cada tramo, ease-in-out sinusoidal). Al volver a
  haber un éxito (`failStreak = 0`) la alarma se detiene y todo vuelve a su color
  normal. **No** afecta al texto, ni a la vista completa, ni a las barras. Es
  independiente del destello puntual; ambos efectos se superponen (base con
  alarma + destello encima).

Separador: sin interacción; solo se redibuja al cambiar su configuración.

---

## 8. Ciclo de actualización (máquina de estados)

```
        ┌────────────┐  timer/arranque/botón/clic-central
        │   IDLE     │───────────────┐
        └────┬───────┘               ▼
             │                  ┌──────────┐
             │                  │ LOADING  │  (indicador visible)
             │                  └────┬─────┘
             │        éxito          │        fallo / vacío / JSON inválido
             │   ┌───────────────────┴───────────────────┐
             ▼   ▼                                        ▼
        ┌──────────┐                               ┌──────────┐
        │  READY   │  (usoData, updatedAt)          │  ERROR   │ (errorMsg)
        └────┬─────┘                               └────┬─────┘
             └──────────────► IDLE ◄───────────────────┘
```

- El estado ERROR **no borra** los últimos datos válidos: la vista puede seguir
  mostrando el último uso conocido y, además, el mensaje de error.
- El indicador de carga solo aparece durante LOADING.

---

## 9. Manejo de errores

Al recibir la respuesta:

1. **Cuerpo vacío** → error "Sin respuesta" (sugerir revisar red / sesión).
2. **JSON no parseable** → error "No se pudo interpretar la respuesta".
3. **Objeto de error de la API** (campo `error`/`detail`) → mostrar su mensaje.
4. **Forma inesperada** (faltan `five_hour`/`seven_day` en Claude, o
   `rate_limit.primary_window` en Codex) → error "Respuesta inesperada".
5. **HTTP 401 / token caducado** → tratar como error; el usuario debe volver a
   iniciar sesión en la CLI correspondiente para regenerar credenciales.

Mensajes claros y no técnicos; el detalle crudo puede añadirse al final.

---

## 10. Localización

- Los nombres de día abreviados están **en español** (§4.1) y son parte de la
  especificación (formato `ddd`).
- Los textos de interfaz están en español en la referencia; en un port se pueden
  externalizar a cadenas traducibles, pero **el formato `ddd` de los días debe
  permanecer en español** salvo que el usuario pida lo contrario.
- Horas siempre en **hora local** del sistema, 24 h, con cero a la izquierda.

---

## 11. Seguridad y privacidad

- El token de sesión **solo** se envía al host correspondiente
  (`api.anthropic.com` para Claude, `chatgpt.com` para Codex), exactamente como
  el `curl` de referencia. **No** debe registrarse, cachearse ni enviarse a
  ningún otro sitio.
- El archivo de credenciales se lee **en local**; trátalo como secreto (no lo
  vuelques en logs ni en la interfaz).
- Todas las peticiones son **HTTPS**. No desactivar la verificación TLS.
- El widget solo **lee** las credenciales; nunca las modifica.

---

## 12. Guía de portabilidad por plataforma

Mapa conceptual (equivalencias):

| Concepto (referencia QML) | macOS | Windows | GNOME/GTK |
|---|---|---|---|
| Widget de panel | Ítem de barra de menú (`NSStatusItem`) o widget WidgetKit | Icono de bandeja (`NotifyIcon`) o widget WinUI 3 | Extensión de GNOME Shell (indicador en el panel) |
| Vista completa emergente | `NSPopover` / ventana | Flyout / ventana WPF-WinUI | `PopupMenu`/`St.BoxLayout` en el panel |
| Dibujo del anillo/línea | SwiftUI `Canvas`/`Path`, Core Graphics | WinUI `Shapes`/`Win2D`, SkiaSharp, GDI+ | `St.DrawingArea` + Cairo |
| Cliente HTTP con cabeceras | `URLSession` | `HttpClient` | `libsoup` (`Soup.Session`) o `fetch` (GJS) |
| Parseo JSON | `Codable`/`JSONSerialization` | `System.Text.Json` | `JSON.parse` (GJS) / `json-glib` |
| Temporizadores | `Timer`/Combine | `DispatcherTimer`/`System.Timers` | `GLib.timeout_add_seconds` |
| Persistencia de config | `UserDefaults` | `ApplicationData`/registro | `Gio.Settings`/GSettings o `Gtk` prefs |
| Selector de color | `NSColorPanel`/SwiftUI `ColorPicker` | `ColorPicker` | `Gtk.ColorChooser` |
| Leer `~` / env | `FileManager`, `ProcessInfo` | `Environment.GetFolderPath`, `%USERPROFILE%` | `GLib.get_home_dir`, `GLib.getenv` |

Recomendaciones generales para cualquier port:

1. **No** shell out a `curl`/`jq`. Lee el archivo de credenciales y haz la
   petición con el cliente HTTP nativo, fijando las cabeceras exactas de §2.
2. Implementa primero el **modelo de datos** (§3) y el **formateo** (§4) como
   funciones puras y testéalas con los ejemplos de §13.
3. Implementa los **dibujos** (§6.2, §6.3, §6.6) con la primitiva de canvas del
   entorno; respeta ángulos, extremos redondeados y half-pixel del separador.
4. Reproduce el **ciclo de actualización** (§8) y los **gestos** (§7): clic
   central = refrescar es un detalle fácil de olvidar.
5. Mantén la **configuración** (§5) con las mismas claves, tipos y valores por
   defecto para que la experiencia sea idéntica.

Notas específicas:

- **GNOME Shell (GJS):** es el port más directo — St + Cairo + Soup se parecen
  mucho a QML + Canvas + red. Un indicador con `PanelMenu.Button`, dibujo en
  `St.DrawingArea.connect('repaint', …)` con Cairo, y `Soup.Session` para el GET.
- **macOS menubar:** dibuja los anillos pequeños como imagen de plantilla del
  `NSStatusItem`; el popover muestra la vista completa. WidgetKit es una
  alternativa (pero no puede hacer red arbitraria con la misma libertad).
- **Windows bandeja:** el icono de bandeja admite poco detalle; considera un
  pequeño widget/flyout WinUI para las barras/anillos. `HttpClient` permite fijar
  `User-Agent` y cabeceras personalizadas sin problema.
- **Cross-platform (Electron/Tauri/Flutter):** el modelo, el formateo y el
  dibujo (Canvas/SVG/`CustomPainter`) se trasladan casi 1:1; cuida el CORS/So
  el `User-Agent` desde el proceso principal/nativo, no desde un WebView.

---

## 13. Ejemplos de referencia

### 13.1 Petición Claude (equivalente cURL)

```bash
TOKEN=$(jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json)
curl -s https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "User-Agent: claude-code/2.1.211" \
  -H "Content-Type: application/json"
```

Respuesta (recortada a lo relevante):

```json
{
  "five_hour":  { "utilization": 26.0, "resets_at": "2026-07-17T21:59:59.314716+00:00" },
  "seven_day":  { "utilization": 2.0,  "resets_at": "2026-07-19T10:59:59.314736+00:00" }
}
```

Render esperado (modo minimalista, panel): dos anillos `26%` y `2%`; etiquetas
`18:59` (5 h, hora local) y `dom 07:59` (semanal, hora local) — ajusta a tu zona.

### 13.2 Petición Codex (equivalente cURL)

```bash
AUTH="${CODEX_HOME:-$HOME/.codex}/auth.json"
TOKEN=$(jq -r '.tokens.access_token' "$AUTH")
ACC=$(jq -r '.tokens.account_id // .account_id' "$AUTH")
curl -s https://chatgpt.com/backend-api/wham/usage \
  -H "Authorization: Bearer $TOKEN" \
  -H "ChatGPT-Account-ID: $ACC" \
  -H "Accept: application/json"
```

Respuesta (recortada):

```json
{
  "plan_type": "plus",
  "rate_limit": {
    "allowed": true,
    "limit_reached": false,
    "primary_window": {
      "used_percent": 0,
      "limit_window_seconds": 604800,
      "reset_after_seconds": 604723,
      "reset_at": 1785266003
    }
  }
}
```

`reset_at = 1785266003` (s) → `2026-07-28T19:13:23Z` → etiqueta semanal
`mar 21:13` (ejemplo, hora local +2). Render: un anillo `0%` con esa etiqueta.

### 13.3 Vectores de prueba de formato

| Función | Entrada | Salida |
|---|---|---|
| `fmtHM` | 2026-07-19 07:05 local | `07:05` |
| `fmtDddHM` | 2026-07-19 (domingo) 07:05 | `dom 07:05` |
| `fmtRemaining` | 90061000 ms | `1d 1h` |
| `fmtRemaining` | 9000000 ms | `2h 30m` |
| `fmtRemaining` | 480000 ms | `8m` |
| `fmtRemaining` | 0 o negativo | `0m` |
| reset nulo | `null` | `-` |
| `colorToHex` | a=1,r=0.8,g=0.47,b=0.36 | `#ffcc785c` |

---

*Implementación de referencia: QML/Qt Quick 5.15 para KDE Plasma 5.27. Licencia
MIT. Este documento es suficiente para reimplementar los tres widgets sin
consultar el código fuente original.*
