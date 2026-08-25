import QtQuick 2.15
import QtQuick.Layouts 1.15
import "lib/format.js" as Fmt

/*
 * Vista completa (Codex): dos barras horizontales (5 h y semanal) con
 * etiquetas de hora de reinicio y tiempo restante.
 *   primary_window   -> límite de 5 horas
 *   secondary_window -> límite semanal
 */
ColumnLayout {
    id: view

    property var usageData: null
    property double now: 0
    property color textColor: "#ffffff"
    property color percentColor: textColor

    spacing: 12

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
        if (!w || !w.reset_at) return null;
        var d = new Date(w.reset_at * 1000);
        return isNaN(d.getTime()) ? null : d;
    }
    function resetInfo(which, weekly) {
        var d = resetDate(which);
        if (!d) return i18n("sin datos");
        var when = weekly ? Fmt.fmtDddHM(d) : Fmt.fmtHM(d);
        var txt = i18n("Reinicia %1", when);
        if (plasmoid.configuration.showRemaining) {
            txt += "  ·  " + i18n("faltan %1", Fmt.fmtRemaining(d.getTime() - view.now));
        }
        return txt;
    }

    UsageBar {
        Layout.fillWidth: true
        title: i18n("Límite 5 horas")
        value: view.util("5h")
        fillColor: plasmoid.configuration.bar5hColor
        trackColor: plasmoid.configuration.barTrackColor
        textColor: view.textColor
        percentColor: view.percentColor
        rightText: view.resetInfo("5h", false)
    }

    UsageBar {
        Layout.fillWidth: true
        title: i18n("Límite semanal")
        value: view.util("weekly")
        fillColor: plasmoid.configuration.bar7dColor
        trackColor: plasmoid.configuration.barTrackColor
        textColor: view.textColor
        percentColor: view.percentColor
        rightText: view.resetInfo("weekly", true)
    }
}
