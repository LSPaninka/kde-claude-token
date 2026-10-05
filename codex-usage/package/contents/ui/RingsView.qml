import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import "lib/format.js" as Fmt

/*
 * Vista minimalista (Codex): dos anillos con el porcentaje en el centro y, bajo
 * cada uno, la hora de reinicio.
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

    function win(which) {
        if (!usageData || !usageData.rate_limit) return null;
        return which === "weekly" ? usageData.rate_limit.secondary_window
                                  : usageData.rate_limit.primary_window;
    }
    function util(which) {
        var w = win(which);
        if (!w || w.used_percent === undefined || w.used_percent === null) return 0;
        return w.used_percent;
    }
    function resetDate(which) {
        var w = win(which);
        if (!w || !w.reset_at || !Fmt.windowStarted(w)) return null;
        var d = new Date(w.reset_at * 1000);
        return isNaN(d.getTime()) ? null : d;
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
            value: view.util("5h")
            caption: "5h"
            ringColor: Plasmoid.configuration.ring5hColor
            trackColor: Plasmoid.configuration.ringTrackColor
            thickness: Plasmoid.configuration.ringThickness
            textColor: view.percentColor
            subTextColor: view.textColor
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: { var d = view.resetDate("5h"); return d ? Fmt.fmtHM(d) : "-"; }
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
            value: view.util("weekly")
            caption: "7d"
            ringColor: Plasmoid.configuration.ring7dColor
            trackColor: Plasmoid.configuration.ringTrackColor
            thickness: Plasmoid.configuration.ringThickness
            textColor: view.percentColor
            subTextColor: view.textColor
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: { var d = view.resetDate("weekly"); return d ? Fmt.fmtDddHM(d) : "-"; }
            color: view.textColor
            font.pixelSize: 13
            font.bold: true
        }
    }
}
