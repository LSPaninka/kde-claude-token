import QtQuick 2.15
import QtQuick.Layouts 1.15
import "lib/format.js" as Fmt

/*
 * Vista completa (Codex): una barra horizontal con el límite semanal,
 * etiqueta de hora de reinicio y tiempo restante.
 */
ColumnLayout {
    id: view

    property var usageData: null
    property double now: 0
    property color textColor: "#ffffff"
    property color percentColor: textColor

    spacing: 12

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
    function resetInfo() {
        var d = resetDate();
        if (!d) return i18n("sin datos");
        var txt = i18n("Reinicia %1", Fmt.fmtDddHM(d));
        if (plasmoid.configuration.showRemaining) {
            txt += "  ·  " + i18n("faltan %1", Fmt.fmtRemaining(d.getTime() - view.now));
        }
        return txt;
    }

    Item { Layout.fillHeight: true }   // centra verticalmente la única barra

    UsageBar {
        Layout.fillWidth: true
        title: i18n("Límite semanal")
        value: view.util()
        fillColor: plasmoid.configuration.barColor
        trackColor: plasmoid.configuration.barTrackColor
        textColor: view.textColor
        percentColor: view.percentColor
        rightText: view.resetInfo()
    }

    Item { Layout.fillHeight: true }
}
