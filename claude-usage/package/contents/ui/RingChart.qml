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

    // ---- Destello de actualización (opcional) ----
    // El arco pasa brevemente a "flashColor" y vuelve al color original.
    // Sólo se activa si se llama a flash(); el fondo del anillo no se toca.
    property color flashColor: "#00e676"      // verde brillante
    property real flashProgress: 0            // 0 = normal, 1 = verde total
    // Color efectivo del arco de progreso (mezcla ringColor -> flashColor)
    readonly property color drawColor: flashProgress <= 0
        ? ringColor
        : Qt.rgba(ringColor.r + (flashColor.r - ringColor.r) * flashProgress,
                  ringColor.g + (flashColor.g - ringColor.g) * flashProgress,
                  ringColor.b + (flashColor.b - ringColor.b) * flashProgress,
                  ringColor.a + (flashColor.a - ringColor.a) * flashProgress)

    function flash() { flashAnim.restart(); }

    SequentialAnimation {
        id: flashAnim
        NumberAnimation { target: ring; property: "flashProgress"; to: 1; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: ring; property: "flashProgress"; to: 0; duration: 550; easing.type: Easing.InQuad }
    }

    implicitWidth: 120
    implicitHeight: 120

    onValueChanged: canvas.requestPaint()
    onDrawColorChanged: canvas.requestPaint()
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
                ctx.strokeStyle = ring.drawColor;
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
            font.pixelSize: Math.max(7, ring.width * 0.28)
            font.bold: true
        }
        Text {
            visible: ring.caption.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.caption
            color: ring.subTextColor
            opacity: 0.8
            font.pixelSize: Math.max(6, ring.width * 0.14)
        }
    }
}
