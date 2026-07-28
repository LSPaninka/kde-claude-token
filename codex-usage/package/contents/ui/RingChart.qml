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
    // El arco pasa brevemente a "flashTarget" y vuelve al color original.
    // Sólo se activa si se llama a flash(); el fondo del anillo no se toca.
    property color flashColor: "#00e676"      // verde brillante (por defecto/éxito)
    property color flashTarget: flashColor    // color usado en el destello actual
    property real flashProgress: 0            // 0 = normal, 1 = color de destello
    // Color efectivo del arco de progreso (mezcla ringColor -> flashTarget)
    readonly property color drawColor: flashProgress <= 0
        ? ringColor
        : Qt.rgba(ringColor.r + (flashTarget.r - ringColor.r) * flashProgress,
                  ringColor.g + (flashTarget.g - ringColor.g) * flashProgress,
                  ringColor.b + (flashTarget.b - ringColor.b) * flashProgress,
                  ringColor.a + (flashTarget.a - ringColor.a) * flashProgress)

    // flash()        -> destello con flashColor (verde)
    // flash("#ff...") -> destello con el color indicado (p. ej. rojo en errores)
    function flash(c) {
        flashTarget = (c !== undefined && c !== null && c !== "") ? c : flashColor;
        flashAnim.restart();
    }

    SequentialAnimation {
        id: flashAnim
        NumberAnimation { target: ring; property: "flashProgress"; to: 1; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: ring; property: "flashProgress"; to: 0; duration: 550; easing.type: Easing.InQuad }
    }

    // ---- Alarma persistente (errores consecutivos) ----
    // Cuando "alarm" es true, el FONDO (pista) del anillo titila sin parar con
    // un fade hacia rojo oscuro. No afecta al arco de progreso ni al texto.
    property bool alarm: false
    property color alarmColor: "#8b0000"      // rojo oscuro
    property real alarmProgress: 0            // 0 = pista normal, 1 = rojo oscuro
    readonly property color trackDrawColor: alarm
        ? Qt.rgba(trackColor.r + (alarmColor.r - trackColor.r) * alarmProgress,
                  trackColor.g + (alarmColor.g - trackColor.g) * alarmProgress,
                  trackColor.b + (alarmColor.b - trackColor.b) * alarmProgress,
                  trackColor.a + (alarmColor.a - trackColor.a) * alarmProgress)
        : trackColor

    onAlarmChanged: if (!alarm) alarmProgress = 0

    SequentialAnimation {
        id: alarmAnim
        running: ring.alarm
        loops: Animation.Infinite
        NumberAnimation { target: ring; property: "alarmProgress"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { target: ring; property: "alarmProgress"; to: 0; duration: 700; easing.type: Easing.InOutSine }
    }

    implicitWidth: 120
    implicitHeight: 120

    onValueChanged: canvas.requestPaint()
    onDrawColorChanged: canvas.requestPaint()
    onTrackDrawColorChanged: canvas.requestPaint()
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
            ctx.strokeStyle = ring.trackDrawColor;
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
