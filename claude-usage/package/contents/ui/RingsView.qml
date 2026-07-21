import QtQuick 2.15
import QtQuick.Layouts 1.15
import "lib/format.js" as Fmt

/*
 * Vista minimalista: dos anillos con el porcentaje en el centro y una etiqueta
 * bajo cada uno con la hora de reinicio.
 *   Anillo 5h -> hh:mm
 *   Anillo 7d -> ddd hh:mm   (ddd = día en español)
 */
RowLayout {
    id: view

    property var usageData: null
    property double now: 0
    property color textColor: "#ffffff"
    property color percentColor: textColor

    spacing: 18

    function util(section) {
        if (!usageData || !usageData[section]) return 0;
        var u = usageData[section].utilization;
        return (u === null || u === undefined) ? 0 : u;
    }
    function resetDate(section) {
        if (!usageData || !usageData[section] || !usageData[section].resets_at) return null;
        return new Date(usageData[section].resets_at);
    }

    // ---- Anillo 5h ----
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        RingChart {
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            Layout.fillHeight: true
            value: view.util("five_hour")
            caption: "5h"
            ringColor: plasmoid.configuration.ring5hColor
            trackColor: plasmoid.configuration.ringTrackColor
            thickness: plasmoid.configuration.ringThickness
            textColor: view.percentColor
            subTextColor: view.textColor
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                var d = view.resetDate("five_hour");
                return d ? Fmt.fmtHM(d) : "-";
            }
            color: view.textColor
            font.pixelSize: 13
            font.bold: true
        }
    }

    // ---- Anillo 7d ----
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        RingChart {
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            Layout.fillHeight: true
            value: view.util("seven_day")
            caption: "7d"
            ringColor: plasmoid.configuration.ring7dColor
            trackColor: plasmoid.configuration.ringTrackColor
            thickness: plasmoid.configuration.ringThickness
            textColor: view.percentColor
            subTextColor: view.textColor
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                var d = view.resetDate("seven_day");
                return d ? Fmt.fmtDddHM(d) : "-";
            }
            color: view.textColor
            font.pixelSize: 13
            font.bold: true
        }
    }
}
