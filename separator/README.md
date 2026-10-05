# Separador de línea — Plasmoide para KDE

Plasmoide (gadget) para **KDE Plasma 6 / Qt 6** que dibuja una simple
**línea separadora** totalmente configurable. Pensado para separar visualmente
grupos de iconos en un panel, pero también funciona en el escritorio.

Sin librerías externas: la línea se dibuja con `Canvas`.

---

## Opciones configurables

Clic derecho sobre el separador → **«Configurar Separador de línea…»**
(pestaña **Apariencia**):

| Opción | Descripción | Por defecto |
|---|---|---|
| **Color** | Color de la línea (con canal alfa). | Blanco |
| **Patrón** | `Sólido`, `Discontinuo` o `Punteado`. | Sólido |
| **Orientación** | `Automática` (perpendicular al panel), `Vertical` u `Horizontal`. | Automática |
| **Grosor** | Grosor de la línea en píxeles (1–40). | 2 px |
| **Longitud** | Longitud como % del espacio disponible (5 %–100 %). | 80 % |
| **Opacidad** | Transparencia de 0 % (invisible) a 100 % (opaca). | 100 % |
| **Longitud del trazo** | Tamaño de cada trazo en `Discontinuo`/`Punteado`. | 6 px |
| **Separación** | Hueco entre trazos en `Discontinuo`/`Punteado`. | 4 px |

- En **orientación automática**, la línea se dibuja perpendicular a la dirección
  del panel: **vertical** en un panel horizontal y **horizontal** en un panel
  vertical (y vertical en el escritorio).
- La opacidad se multiplica por el canal alfa del color, así que puedes combinar
  ambos.

---

## Instalación

```bash
cd separator
./install.sh
```

Luego: clic derecho en el panel o el escritorio → **«Añadir elementos gráficos»**
→ **«Separador de línea»**. Para colocarlo en un panel, arrástralo entre dos
iconos. Para **actualizar** vuelve a ejecutar `./install.sh`; para
**desinstalar**: `./install.sh --remove`.

---

## Licencia

MIT. Ver [LICENSE](../LICENSE).
