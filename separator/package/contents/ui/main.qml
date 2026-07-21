import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami

/*
 * Separador: dibuja una línea configurable (color, patrón, grosor, longitud,
 * transparencia y orientación). Sin librerías externas: se dibuja con Canvas.
 */
Item {
    id: root

    // Renderiza la línea directamente en el panel (sin icono ni ventana
    // emergente), igual que el «Separador de paneles» oficial.
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    // ---- Configuración ----
    readonly property color baseColor: plasmoid.configuration.lineColor
    readonly property real opacity01: Math.max(0, Math.min(100, plasmoid.configuration.opacityPercent)) / 100
    readonly property color effColor: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * opacity01)
    readonly property int thickness: plasmoid.configuration.thickness
    readonly property string pattern: plasmoid.configuration.pattern
    readonly property real lengthPercent: plasmoid.configuration.lengthPercent
    readonly property int dashLength: plasmoid.configuration.dashLength
    readonly property int gapLength: plasmoid.configuration.gapLength

    // ---- Orientación ----
    readonly property bool panelVertical: plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool vertical: {
        var o = plasmoid.configuration.orientation;
        if (o === "vertical") return true;
        if (o === "horizontal") return false;
        // auto: perpendicular a la dirección del panel (en escritorio, vertical)
        return !panelVertical;
    }

    // Margen para poder seleccionar/mover el applet con el ratón
    readonly property int pad: Math.max(2, Kirigami.Units.smallSpacing)

    // El applet es fino en el eje del grosor y se estira en el otro.
    Layout.fillWidth: !vertical
    Layout.fillHeight: vertical
    Layout.preferredWidth:  vertical ? (thickness + pad * 2) : Kirigami.Units.gridUnit * 4
    Layout.preferredHeight: vertical ? Kirigami.Units.gridUnit * 4 : (thickness + pad * 2)
    Layout.minimumWidth:  vertical ? (thickness + pad * 2) : Kirigami.Units.gridUnit
    Layout.minimumHeight: vertical ? Kirigami.Units.gridUnit : (thickness + pad * 2)

    onEffColorChanged: canvas.requestPaint()
    onThicknessChanged: canvas.requestPaint()
    onPatternChanged: canvas.requestPaint()
    onLengthPercentChanged: canvas.requestPaint()
    onDashLengthChanged: canvas.requestPaint()
    onGapLengthChanged: canvas.requestPaint()
    onVerticalChanged: canvas.requestPaint()

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
