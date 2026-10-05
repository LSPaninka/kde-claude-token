import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "lib/format.js" as Fmt

PlasmoidItem {
    id: root

    // -------- Estado --------
    property var usageData: null
    property string errorMsg: ""
    property bool loading: false
    property double lastUpdate: 0
    property double now: Date.now()

    readonly property color txtColor: Plasmoid.configuration.useThemeTextColor
                                       ? Kirigami.Theme.textColor
                                       : Plasmoid.configuration.labelColor
    readonly property color pctColor: Plasmoid.configuration.useThemeTextColor
                                       ? Kirigami.Theme.textColor
                                       : Plasmoid.configuration.percentColor

    readonly property string planType: (usageData && usageData.plan_type) ? usageData.plan_type : ""

    signal usageUpdated(bool ok)
    property int failStreak: 0
    readonly property bool alarmActive: Plasmoid.configuration.errorBlink && failStreak >= 2

    // -------- Créditos de reinicio (reset credits) --------
    property var resetData: null
    readonly property bool resetAvailable: resetData && resetData.available_count > 0

    // =====================================================================
    //  Acceso a los datos. Codex expone dos ventanas:
    //    primary_window   -> límite de 5 horas
    //    secondary_window -> límite semanal
    // =====================================================================
    function windowObj(which) {
        if (!usageData || !usageData.rate_limit) return null;
        return which === "weekly" ? usageData.rate_limit.secondary_window
                                  : usageData.rate_limit.primary_window;
    }
    function utilOf(which) {
        var w = windowObj(which);
        if (!w || w.used_percent === undefined || w.used_percent === null) return 0;
        return w.used_percent;
    }
    function resetDateOf(which) {
        var w = windowObj(which);
        // Sin reset_at o periodo aún no iniciado -> "-"
        if (!w || !w.reset_at || !Fmt.windowStarted(w)) return null;
        var d = new Date(w.reset_at * 1000);   // segundos Unix
        return isNaN(d.getTime()) ? null : d;
    }
    function resetLabel(which, weekly) {
        var d = resetDateOf(which);
        if (!d) return "-";
        return weekly ? Fmt.fmtDddHM(d) : Fmt.fmtHM(d);
    }

    // Texto del tooltip del icono de reinicios disponibles
    function resetTooltip() {
        if (!resetData) return "";
        var lines = [ i18n("Resets: %1", resetData.available_count) ];
        var arr = resetData.credits || [];
        for (var i = 0; i < arr.length; i++) {
            var c = arr[i];
            var st = c.status ? (c.status.charAt(0).toUpperCase() + c.status.slice(1)) : "";
            lines.push("- " + (c.title || "") + ": "
                       + Fmt.fmtDM(c.granted_at) + " a " + Fmt.fmtDM(c.expires_at)
                       + " [" + st + "]");
        }
        return lines.join("\n");
    }

    // =====================================================================
    //  Obtención de datos
    // =====================================================================
    // Construye el comando de shell que lee las credenciales y consulta la URL.
    function buildCodexCommand(url) {
        var path = Plasmoid.configuration.credentialsPath;
        if (!path || path.trim() === "") {
            path = "${CODEX_HOME:-$HOME/.codex}/auth.json";
        } else {
            path = path.replace(/^~(?=\/|$)/, "$HOME");
        }
        var p = '"' + path + '"';

        return 'AUTH=' + p + '; ' +
               'TOKEN=$(jq -r \'.tokens.access_token // empty\' "$AUTH" 2>/dev/null); ' +
               'ACC=$(jq -r \'.tokens.account_id // .account_id // empty\' "$AUTH" 2>/dev/null); ' +
               'if [ -z "$TOKEN" ]; then TOKEN=$(sed -n \'s/.*"access_token"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p\' "$AUTH" | head -n1); fi; ' +
               'if [ -z "$ACC" ]; then ACC=$(sed -n \'s/.*"account_id"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p\' "$AUTH" | head -n1); fi; ' +
               'curl -s ' + url + ' ' +
               '-H "Authorization: Bearer $TOKEN" ' +
               '-H "ChatGPT-Account-ID: $ACC" ' +
               '-H "Accept: application/json"';
    }
    function buildCommand()      { return buildCodexCommand("https://chatgpt.com/backend-api/wham/usage"); }
    function buildResetCommand() { return buildCodexCommand("https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"); }

    function refresh()       { root.loading = true; usageSource.exec(buildCommand()); }
    function refreshResets() { resetSource.exec(buildResetCommand()); }
    function refreshAll()    { refresh(); refreshResets(); }

    function handleResult(stdout, stderr) {
        root.loading = false;
        var ok = false;
        var txt = (stdout || "").trim();
        if (txt.length === 0) {
            root.errorMsg = (stderr && stderr.trim().length)
                ? stderr.trim()
                : i18n("Sin respuesta. ¿Está 'curl' instalado y la sesión de Codex iniciada?");
        } else {
            try {
                var obj = JSON.parse(txt);
                if (obj.error) {
                    root.errorMsg = (obj.error.message || obj.error).toString();
                } else if (!obj.rate_limit || !obj.rate_limit.primary_window) {
                    root.errorMsg = obj.detail ? obj.detail.toString()
                                               : i18n("Respuesta inesperada de la API");
                } else {
                    root.usageData = obj;
                    root.errorMsg = "";
                    root.lastUpdate = Date.now();
                    ok = true;
                }
            } catch (e) {
                root.errorMsg = i18n("No se pudo interpretar la respuesta: %1", e.toString());
            }
        }
        root.failStreak = ok ? 0 : (root.failStreak + 1);
        root.usageUpdated(ok);
    }

    function handleResetResult(stdout) {
        var txt = (stdout || "").trim();
        if (txt.length === 0) return;   // conserva el último estado conocido
        try {
            var obj = JSON.parse(txt);
            if (obj && typeof obj.available_count === "number") {
                root.resetData = obj;
            }
        } catch (e) { /* se ignora: se conserva el último estado */ }
    }

    Plasma5Support.DataSource {
        id: usageSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var stdout = data["stdout"] || "";
            var stderr = data["stderr"] || "";
            usageSource.disconnectSource(sourceName);
            root.handleResult(stdout, stderr);
        }
        function exec(cmd) { connectSource(cmd); }
    }

    Plasma5Support.DataSource {
        id: resetSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var stdout = data["stdout"] || "";
            resetSource.disconnectSource(sourceName);
            root.handleResetResult(stdout);
        }
        function exec(cmd) { connectSource(cmd); }
    }

    Timer {
        id: pollTimer
        interval: Math.max(15, Plasmoid.configuration.refreshInterval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAll()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // =====================================================================
    //  Representación compacta (panel) — dos anillos + hora de reinicio.
    //  Clic izquierdo: abrir la vista completa. Clic central: actualizar.
    // =====================================================================
    compactRepresentation: MouseArea {
        id: cr
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) root.refreshAll();
            else root.expanded = !root.expanded;
        }

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property real scale01: Math.max(0.5, Math.min(1.0, Plasmoid.configuration.panelIconScale / 100))
        readonly property real thickness: vertical ? cr.width : cr.height
        readonly property real ringSize: Math.round(Math.max(8, thickness * scale01))
        readonly property int gap: Kirigami.Units.smallSpacing

        Layout.fillHeight: !vertical
        Layout.fillWidth: vertical
        Layout.preferredWidth:  vertical ? -1 : content.implicitWidth
        Layout.preferredHeight: vertical ? content.implicitHeight : -1
        Layout.minimumWidth: Layout.preferredWidth

        // Destello al actualizarse: verde (arco) + verde oscuro (fondo) si ok;
        // rojo (arco) si falla.
        Connections {
            target: root
            function onUsageUpdated(ok) {
                if (ok) {
                    ring5h.flash("#00e676", "#006400");
                    ring7d.flash("#00e676", "#006400");
                } else {
                    ring5h.flash("#ff1744", "");
                    ring7d.flash("#ff1744", "");
                }
            }
        }

        GridLayout {
            id: content
            anchors.centerIn: parent
            columns: cr.vertical ? 1 : 2
            rowSpacing: cr.gap
            columnSpacing: cr.gap * 2

            // ---- Par 5h ----
            RowLayout {
                spacing: cr.gap
                RingChart {
                    id: ring5h
                    Layout.preferredWidth: cr.ringSize
                    Layout.preferredHeight: cr.ringSize
                    value: root.utilOf("5h")
                    ringColor: Plasmoid.configuration.ring5hColor
                    trackColor: Plasmoid.configuration.ringTrackColor
                    thickness: Math.max(2, cr.ringSize * 0.15)
                    textColor: root.pctColor
                    alarm: root.alarmActive
                }
                Text {
                    text: root.resetLabel("5h", false)
                    color: root.txtColor
                    font.bold: true
                    font.pixelSize: Math.max(8, cr.ringSize * 0.30)
                }
            }

            // ---- Par 7d ----
            RowLayout {
                spacing: cr.gap
                RingChart {
                    id: ring7d
                    Layout.preferredWidth: cr.ringSize
                    Layout.preferredHeight: cr.ringSize
                    value: root.utilOf("weekly")
                    ringColor: Plasmoid.configuration.ring7dColor
                    trackColor: Plasmoid.configuration.ringTrackColor
                    thickness: Math.max(2, cr.ringSize * 0.15)
                    textColor: root.pctColor
                    alarm: root.alarmActive
                }
                Text {
                    text: root.resetLabel("weekly", true)
                    color: root.txtColor
                    font.bold: true
                    font.pixelSize: Math.max(8, cr.ringSize * 0.30)
                }
            }
        }
    }

    // =====================================================================
    //  Representación completa
    // =====================================================================
    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: Kirigami.Units.gridUnit * 11
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 12

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing * 2

            // ---- Encabezado ----
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: "cloudstatus"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PlasmaComponents.Label {
                    text: root.planType.length > 0
                          ? i18n("Uso de Codex — %1", root.planType)
                          : i18n("Uso de Codex")
                    font.bold: true
                    color: root.txtColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                PlasmaComponents.BusyIndicator {
                    running: root.loading
                    visible: root.loading
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: root.refreshAll()
                    QQC2.ToolTip.text: i18n("Actualizar")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: 500
                }
            }

            // ---- Cuerpo: barras o anillos ----
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: Plasmoid.configuration.displayMode === "rings"
                                 ? ringsComponent : barsComponent
            }
            Component {
                id: barsComponent
                BarsView {
                    usageData: root.usageData
                    now: root.now
                    textColor: root.txtColor
                    percentColor: root.pctColor
                }
            }
            Component {
                id: ringsComponent
                RingsView {
                    usageData: root.usageData
                    now: root.now
                    textColor: root.txtColor
                    percentColor: root.pctColor
                }
            }

            // ---- Pie ----
            RowLayout {
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: "gift"
                    fallback: "package-x-generic"
                    visible: root.resetAvailable
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        QQC2.ToolTip.text: root.resetTooltip()
                        QQC2.ToolTip.visible: containsMouse && root.resetTooltip() !== ""
                        QQC2.ToolTip.delay: 300
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.errorMsg.length > 0
                    text: "⚠ " + root.errorMsg
                    color: Kirigami.Theme.negativeTextColor
                    font.pixelSize: Kirigami.Units.gridUnit * 0.55
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.errorMsg.length === 0 && root.lastUpdate > 0
                    horizontalAlignment: Text.AlignRight
                    text: i18n("Actualizado %1", Fmt.fmtHM(new Date(root.lastUpdate)))
                    opacity: 0.6
                    color: root.txtColor
                    font.pixelSize: Kirigami.Units.gridUnit * 0.55
                }
            }
        }
    }
}
