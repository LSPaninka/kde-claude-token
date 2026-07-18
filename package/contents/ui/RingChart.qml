import QtQuick 2.15

/*
 * Anillo (donut) con el porcentaje en el centro.
 * Dibujado con Canvas, sin librerías externas.
 */
Item {
    id: ring

    property real value: 0            // 0..100
    property color ringColor: "#7c5cff"
    property color trackColor: "#40808080"
    property color textColor: "#ffffff"
    property color subTextColor: "#ffffff"
    property real thickness: Math.max(4, Math.min(width, height) * 0.12)
    property string caption: ""       // pequeña etiqueta bajo el porcentaje (ej: "5h")

    implicitWidth: 120
    implicitHeight: 120

    onValueChanged: canvas.requestPaint()
    onRingColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onThicknessChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width, h = height;
            var cx = w / 2, cy = h / 2;
            var r = Math.min(w, h) / 2 - ring.thickness / 2 - 1;
            if (r <= 0) return;

            // Pista de fondo
            ctx.beginPath();
            ctx.lineWidth = ring.thickness;
            ctx.strokeStyle = ring.trackColor;
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.stroke();

            // Progreso
            var v = Math.max(0, Math.min(100, ring.value));
            if (v > 0) {
                var start = -Math.PI / 2;
                var end = start + (2 * Math.PI) * (v / 100);
                ctx.beginPath();
                ctx.lineWidth = ring.thickness;
                ctx.strokeStyle = ring.ringColor;
                ctx.lineCap = "round";
                ctx.arc(cx, cy, r, start, end);
                ctx.stroke();
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(ring.value) + "%"
            color: ring.textColor
            font.pixelSize: Math.max(12, ring.width * 0.24)
            font.bold: true
        }
        Text {
            visible: ring.caption.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.caption
            color: ring.subTextColor
            opacity: 0.8
            font.pixelSize: Math.max(9, ring.width * 0.13)
        }
    }
}
