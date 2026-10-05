import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

/*
 * Separador: dibuja una línea configurable (color, patrón, grosor, longitud,
 * transparencia y orientación). Sin librerías externas: se dibuja con Canvas.
 */
PlasmoidItem {
    id: root

    // Renderiza la línea directamente en el panel (sin icono ni ventana
    // emergente), igual que el «Separador de paneles» oficial.
    preferredRepresentation: fullRepresentation

    // ---- Configuración ----
    readonly property color baseColor: Plasmoid.configuration.lineColor
    readonly property real opacity01: Math.max(0, Math.min(100, Plasmoid.configuration.opacityPercent)) / 100
    readonly property color effColor: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * opacity01)
    readonly property int thickness: Plasmoid.configuration.thickness
    readonly property string pattern: Plasmoid.configuration.pattern
    readonly property real lengthPercent: Plasmoid.configuration.lengthPercent
    readonly property int dashLength: Plasmoid.configuration.dashLength
    readonly property int gapLength: Plasmoid.configuration.gapLength

    // ---- Orientación ----
    readonly property bool panelVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool vertical: {
        var o = Plasmoid.configuration.orientation;
        if (o === "vertical") return true;
        if (o === "horizontal") return false;
        // auto: perpendicular a la dirección del panel (en escritorio, vertical)
        return !panelVertical;
    }

    // Margen para poder seleccionar/mover el applet con el ratón
    readonly property int pad: Math.max(2, Kirigami.Units.smallSpacing)

    fullRepresentation: Item {
        // El applet es fino en el eje del grosor y se estira en el otro.
        Layout.fillWidth: !root.vertical
        Layout.fillHeight: root.vertical
        Layout.preferredWidth:  root.vertical ? (root.thickness + root.pad * 2) : Kirigami.Units.gridUnit * 4
        Layout.preferredHeight: root.vertical ? Kirigami.Units.gridUnit * 4 : (root.thickness + root.pad * 2)
        Layout.minimumWidth:  root.vertical ? (root.thickness + root.pad * 2) : Kirigami.Units.gridUnit
        Layout.minimumHeight: root.vertical ? Kirigami.Units.gridUnit : (root.thickness + root.pad * 2)

        // Redibujar cuando cambia cualquier opción
        Connections {
            target: root
            function onEffColorChanged() { canvas.requestPaint(); }
            function onThicknessChanged() { canvas.requestPaint(); }
            function onPatternChanged() { canvas.requestPaint(); }
            function onLengthPercentChanged() { canvas.requestPaint(); }
            function onDashLengthChanged() { canvas.requestPaint(); }
            function onGapLengthChanged() { canvas.requestPaint(); }
            function onVerticalChanged() { canvas.requestPaint(); }
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width, h = height;

                ctx.strokeStyle = root.effColor;
                ctx.lineWidth = root.thickness;

                if (root.pattern === "dashed") {
                    ctx.lineCap = "butt";
                    ctx.setLineDash([root.dashLength, root.gapLength]);
                } else if (root.pattern === "dotted") {
                    // Puntos redondos: trazo mínimo + extremos redondeados
                    ctx.lineCap = "round";
                    ctx.setLineDash([1, root.gapLength + root.thickness]);
                } else {
                    ctx.lineCap = "butt";
                    ctx.setLineDash([]);
                }

                ctx.beginPath();
                if (root.vertical) {
                    var x = Math.round(w / 2) + (root.thickness % 2 ? 0.5 : 0);
                    var len = h * root.lengthPercent / 100;
                    var y0 = (h - len) / 2;
                    ctx.moveTo(x, y0);
                    ctx.lineTo(x, y0 + len);
                } else {
                    var y = Math.round(h / 2) + (root.thickness % 2 ? 0.5 : 0);
                    var lenH = w * root.lengthPercent / 100;
                    var x0 = (w - lenH) / 2;
                    ctx.moveTo(x0, y);
                    ctx.lineTo(x0 + lenH, y);
                }
                ctx.stroke();
            }
        }
    }
}
