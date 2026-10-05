import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import "lib/format.js" as Fmt

/*
 * Vista completa: dos barras horizontales (5h y semanal) con etiquetas
 * de hora de reinicio y tiempo restante.
 */
ColumnLayout {
    id: view

    property var usageData: null      // objeto JSON de la API
    property double now: 0            // Date.now() actual (para recalcular restante)
    property color textColor: "#ffffff"
    property color percentColor: textColor

    spacing: 12

    function util(section) {
        if (!usageData || !usageData[section]) return 0;
        var u = usageData[section].utilization;
        return (u === null || u === undefined) ? 0 : u;
    }
    function resetDate(section) {
        if (!usageData || !usageData[section] || !usageData[section].resets_at) return null;
        return new Date(usageData[section].resets_at);
    }
    function resetInfo(section, weekly) {
        var d = resetDate(section);
        if (!d) return i18n("sin datos");
        var when = weekly ? Fmt.fmtDddHM(d) : Fmt.fmtHM(d);
        var txt = i18n("Reinicia %1", when);
        if (Plasmoid.configuration.showRemaining) {
            txt += "  ·  " + i18n("faltan %1", Fmt.fmtRemaining(d.getTime() - view.now));
        }
        return txt;
    }

    UsageBar {
        Layout.fillWidth: true
        title: i18n("Límite 5 horas")
        value: view.util("five_hour")
        fillColor: Plasmoid.configuration.bar5hColor
        trackColor: Plasmoid.configuration.barTrackColor
        textColor: view.textColor
        percentColor: view.percentColor
        rightText: view.resetInfo("five_hour", false)
    }

    UsageBar {
        Layout.fillWidth: true
        title: i18n("Límite semanal")
        value: view.util("seven_day")
        fillColor: Plasmoid.configuration.bar7dColor
        trackColor: Plasmoid.configuration.barTrackColor
        textColor: view.textColor
        percentColor: view.percentColor
        rightText: view.resetInfo("seven_day", true)
    }
}
