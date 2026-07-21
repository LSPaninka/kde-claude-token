import QtQuick 2.15
import QtQuick.Layouts 1.15

/*
 * Barra horizontal de progreso con título, porcentaje y una línea inferior
 * de información (hora de reinicio / tiempo restante).
 */
Item {
    id: bar

    property real value: 0            // 0..100
    property color fillColor: "#7c5cff"
    property color trackColor: "#40808080"
    property color textColor: "#ffffff"
    property color percentColor: textColor
    property string title: ""
    property string rightText: ""     // información bajo la barra

    implicitHeight: 48
    Layout.fillWidth: true

    Column {
        anchors.fill: parent
        spacing: 3

        RowLayout {
            width: parent.width
            Text {
                text: bar.title
                color: bar.textColor
                font.bold: true
                font.pixelSize: 12
                Layout.fillWidth: true
            }
            Text {
                text: Math.round(bar.value) + "%"
                color: bar.percentColor
                font.bold: true
                font.pixelSize: 12
            }
        }

        Rectangle {
            width: parent.width
            height: 14
            radius: height / 2
            color: bar.trackColor

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: Math.max(0, Math.min(1, bar.value / 100)) * parent.width
                color: bar.fillColor
                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            width: parent.width
            text: bar.rightText
            color: bar.textColor
            opacity: 0.8
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }
}
