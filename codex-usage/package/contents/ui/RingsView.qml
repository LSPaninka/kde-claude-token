import QtQuick 2.15
import QtQuick.Layouts 1.15
import "lib/format.js" as Fmt

/*
 * Vista minimalista (Codex): un anillo con el porcentaje en el centro y, debajo,
 * la hora de reinicio semanal en formato "ddd hh:mm" (día en español).
 */
ColumnLayout {
    id: view

    property var usageData: null
    property double now: 0
    property color textColor: "#ffffff"
    property color percentColor: textColor

    spacing: 6

    function primary() {
        return (usageData && usageData.rate_limit) ? usageData.rate_limit.primary_window : null;
    }
    function util() {
        var p = primary();
        if (!p || p.used_percent === undefined || p.used_percent === null) return 0;
        return p.used_percent;
    }
    function resetDate() {
        var p = primary();
        if (!p || !p.reset_at) return null;
        var d = new Date(p.reset_at * 1000);
        return isNaN(d.getTime()) ? null : d;
    }

    RingChart {
        Layout.alignment: Qt.AlignCenter
        Layout.fillWidth: true
        Layout.fillHeight: true
        value: view.util()
        caption: "7d"
        ringColor: plasmoid.configuration.ringColor
        trackColor: plasmoid.configuration.ringTrackColor
        thickness: plasmoid.configuration.ringThickness
        textColor: view.percentColor
        subTextColor: view.textColor
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: {
            var d = view.resetDate();
            return d ? Fmt.fmtDddHM(d) : "-";
        }
        color: view.textColor
        font.pixelSize: 13
        font.bold: true
    }
}
