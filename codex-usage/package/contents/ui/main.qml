import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami
import "lib/format.js" as Fmt

Item {
    id: root

    // -------- Estado --------
    property var usageData: null       // objeto JSON de la respuesta de la API
    property string errorMsg: ""
    property bool loading: false
    property double lastUpdate: 0
    property double now: Date.now()

    readonly property color txtColor: plasmoid.configuration.useThemeTextColor
                                       ? Kirigami.Theme.textColor
                                       : plasmoid.configuration.labelColor
    readonly property color pctColor: plasmoid.configuration.useThemeTextColor
                                       ? Kirigami.Theme.textColor
                                       : plasmoid.configuration.percentColor

    // Plan (plus / pro / ...) informado por la API
    readonly property string planType: (usageData && usageData.plan_type) ? usageData.plan_type : ""

    // Emitida al terminar cada obtención de datos (ok=true éxito, false error)
    signal usageUpdated(bool ok)

    // Errores consecutivos; la alarma se activa a partir de 2 seguidos.
    property int failStreak: 0
    readonly property bool alarmActive: plasmoid.configuration.errorBlink && failStreak >= 2

    // =====================================================================
    //  Acceso a los datos (Codex sólo expone un límite: primary_window)
    // =====================================================================
    readonly property var primary: (usageData && usageData.rate_limit)
                                    ? usageData.rate_limit.primary_window : null

    function util() {
        if (!primary || primary.used_percent === undefined || primary.used_percent === null) return 0;
        return primary.used_percent;
    }
    function resetDate() {
        if (!primary || !primary.reset_at) return null;
        var d = new Date(primary.reset_at * 1000);   // reset_at está en segundos Unix
        return isNaN(d.getTime()) ? null : d;
    }
    // Etiqueta de reinicio semanal: "ddd hh:mm". "-" si no hay límite.
    function resetLabel() {
        var d = resetDate();
        return d ? Fmt.fmtDddHM(d) : "-";
    }

    // =====================================================================
    //  Obtención de datos
    // =====================================================================
    function buildCommand() {
        var path = plasmoid.configuration.credentialsPath;
        if (!path || path.trim() === "") {
            path = "${CODEX_HOME:-$HOME/.codex}/auth.json";
        } else {
            path = path.replace(/^~(?=\/|$)/, "$HOME");
        }
        var p = '"' + path + '"';   // entre comillas dobles => se expande $HOME / $CODEX_HOME

        return 'AUTH=' + p + '; ' +
               'TOKEN=$(jq -r \'.tokens.access_token // empty\' "$AUTH" 2>/dev/null); ' +
               'ACC=$(jq -r \'.tokens.account_id // .account_id // empty\' "$AUTH" 2>/dev/null); ' +
               'if [ -z "$TOKEN" ]; then TOKEN=$(sed -n \'s/.*"access_token"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p\' "$AUTH" | head -n1); fi; ' +
               'if [ -z "$ACC" ]; then ACC=$(sed -n \'s/.*"account_id"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p\' "$AUTH" | head -n1); fi; ' +
               'curl -s https://chatgpt.com/backend-api/wham/usage ' +
               '-H "Authorization: Bearer $TOKEN" ' +
               '-H "ChatGPT-Account-ID: $ACC" ' +
               '-H "Accept: application/json"';
    }

    function refresh() {
        root.loading = true;
        usageSource.exec(buildCommand());
    }

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

    PlasmaCore.DataSource {
        id: usageSource
        engine: "executable"
        connectedSources: []

        onNewData: {
            var stdout = data["stdout"] || "";
            var stderr = data["stderr"] || "";
            disconnectSource(sourceName);
            root.handleResult(stdout, stderr);
        }

        function exec(cmd) {
            connectSource(cmd);
        }
    }

    Timer {
        id: pollTimer
        interval: Math.max(15, plasmoid.configuration.refreshInterval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // =====================================================================
    //  Representación compacta (panel) — un anillo escalable + hora de reinicio.
    //  Clic izquierdo: abrir la vista completa. Clic central: actualizar.
    // =====================================================================
    Plasmoid.compactRepresentation: MouseArea {
        id: cr
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: {
            if (mouse.button === Qt.MiddleButton) {
                root.refresh();
            } else {
                plasmoid.expanded = !plasmoid.expanded;
            }
        }

        readonly property bool vertical: plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property real scale01: Math.max(0.5, Math.min(1.0, plasmoid.configuration.panelIconScale / 100))
        readonly property real thickness: vertical ? cr.width : cr.height
        readonly property real ringSize: Math.round(Math.max(8, thickness * scale01))
        readonly property int gap: Kirigami.Units.smallSpacing

        Layout.fillHeight: !vertical
        Layout.fillWidth: vertical
        Layout.preferredWidth:  vertical ? -1 : content.implicitWidth
        Layout.preferredHeight: vertical ? content.implicitHeight : -1
        Layout.minimumWidth: Layout.preferredWidth

        // Destello al actualizarse: verde si tuvo éxito, rojo si falló.
        Connections {
            target: root
            function onUsageUpdated(ok) {
                if (ok) ring.flash("#00e676", "#006400");   // arco verde + fondo verde oscuro
                else ring.flash("#ff1744", "");             // arco rojo (fondo => alarma)
            }
        }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: cr.gap

            RingChart {
                id: ring
                Layout.preferredWidth: cr.ringSize
                Layout.preferredHeight: cr.ringSize
                value: root.util()
                ringColor: plasmoid.configuration.ringColor
                trackColor: plasmoid.configuration.ringTrackColor
                thickness: Math.max(2, cr.ringSize * 0.15)
                textColor: root.pctColor
                alarm: root.alarmActive
            }
            Text {
                text: root.resetLabel()
                color: root.txtColor
                font.bold: true
                font.pixelSize: Math.max(8, cr.ringSize * 0.30)
            }
        }
    }

    // =====================================================================
    //  Representación completa
    // =====================================================================
    Plasmoid.fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: Kirigami.Units.gridUnit * 9
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 10

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
                    onClicked: root.refresh()
                    QQC2.ToolTip.text: i18n("Actualizar")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: 500
                }
            }

            // ---- Cuerpo: barra o anillo ----
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: plasmoid.configuration.displayMode === "rings"
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
