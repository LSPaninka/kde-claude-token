import QtQuick

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

    // Mezcla lineal de dos colores (t: 0..1)
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t);
    }

    // ---- Destello de actualización (opcional) ----
    // Al llamar a flash() el ARCO pasa brevemente a "flashArcColor" y, si se
    // indica, el FONDO pasa a "flashTrackColor"; ambos vuelven al color original.
    property color flashColor: "#00e676"      // verde brillante (arco, por defecto/éxito)
    property color flashArcColor: flashColor  // color del arco en el destello actual
    property color flashTrackColor: "#006400" // color del fondo en el destello actual
    property bool  flashTrackEnabled: false   // ¿el destello también tiñe el fondo?
    property real  flashProgress: 0           // 0 = normal, 1 = color de destello

    // flash(arco)        -> destella el arco con "arco" (o verde por defecto)
    // flash(arco, fondo) -> además tiñe el fondo con "fondo"
    function flash(arcColor, trackFlashColor) {
        flashArcColor = (arcColor !== undefined && arcColor !== null && arcColor !== "") ? arcColor : flashColor;
        if (trackFlashColor !== undefined && trackFlashColor !== null && trackFlashColor !== "") {
            flashTrackColor = trackFlashColor;
            flashTrackEnabled = true;
        } else {
            flashTrackEnabled = false;
        }
        flashAnim.restart();
    }

    SequentialAnimation {
        id: flashAnim
        NumberAnimation { target: ring; property: "flashProgress"; to: 1; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: ring; property: "flashProgress"; to: 0; duration: 550; easing.type: Easing.InQuad }
    }

    // ---- Alarma persistente (errores consecutivos) ----
    // Cuando "alarm" es true, en cada tic (fade en bucle) el FONDO titila hacia
    // rojo oscuro y el ARCO hacia rojo brillante, sincronizados. No toca el texto.
    property bool alarm: false
    property color alarmColor: "#8b0000"      // rojo oscuro (fondo)
    property color alarmArcColor: "#ff1744"   // rojo brillante (arco)
    property real alarmProgress: 0            // 0 = normal, 1 = pico del tic

    // Color efectivo del arco: base (con alarma) + destello encima.
    readonly property color drawColor: {
        var base = alarm ? mix(ringColor, alarmArcColor, alarmProgress) : ringColor;
        return flashProgress > 0 ? mix(base, flashArcColor, flashProgress) : base;
    }
    // Color efectivo del fondo/pista: base (con alarma) + destello encima.
    readonly property color trackDrawColor: {
        var base = alarm ? mix(trackColor, alarmColor, alarmProgress) : trackColor;
        return (flashProgress > 0 && flashTrackEnabled) ? mix(base, flashTrackColor, flashProgress) : base;
    }

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
