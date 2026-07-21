import QtQuick 2.15
import QtQuick.Dialogs 1.3
import "lib/format.js" as Fmt

/*
 * Muestra un rectángulo con el color actual; al pulsarlo abre un selector de
 * color. Emite picked(hex) con la cadena #AARRGGBB elegida.
 */
Item {
    id: cb

    property color currentColor: "#ffffffff"
    signal picked(string hex)

    implicitWidth: 64
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: cb.currentColor
        border.color: Qt.rgba(0, 0, 0, 0.4)
        border.width: 1

        // Ajedrezado tenue para percibir la transparencia
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 3
            color: "transparent"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: dlg.open()
        }
    }

    ColorDialog {
        id: dlg
        title: i18n("Elegir color")
        showAlphaChannel: true
        color: cb.currentColor
        onAccepted: cb.picked(Fmt.colorToHex(dlg.color))
    }
}
