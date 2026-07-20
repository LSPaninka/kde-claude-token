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

    // Color de texto (tema o personalizado)
    readonly property color txtColor: plasmoid.configuration.useThemeTextColor
                                       ? Kirigami.Theme.textColor
                                       : plasmoid.configuration.labelColor
    readonly property color pctColor: plasmoid.configuration.useThemeTextColor
                                       ? Kirigami.Theme.textColor
                                       : plasmoid.configuration.percentColor

    // No se fuerza la representación: en el panel se usa la compacta (anillos
    // minimalistas) y al pulsar se abre la completa; en el escritorio se usa
    // directamente la completa.

    // Porcentaje de utilización de una sección ("five_hour" / "seven_day")
    function utilOf(section) {
        if (!usageData || !usageData[section]) return 0;
        var u = usageData[section].utilization;
        return (u === null || u === undefined) ? 0 : u;
    }

    // Fecha de reinicio de una sección, o null si no está establecida
    function resetDateOf(section) {
        if (!usageData || !usageData[section] || !usageData[section].resets_at) return null;
        var d = new Date(usageData[section].resets_at);
        return isNaN(d.getTime()) ? null : d;
    }

    // Etiqueta de reinicio: "hh:mm" (o "ddd hh:mm" si weekly). "-" si no hay límite.
    function resetLabel(section, weekly) {
        var d = resetDateOf(section);
        if (!d) return "-";
        return weekly ? Fmt.fmtDddHM(d) : Fmt.fmtHM(d);
    }

    // =====================================================================
    //  Obtención de datos
    // =====================================================================

    // Construye el comando de shell que lee el token y consulta la API.
    // Equivale al curl de ejemplo, pero sin depender de jq (usa jq si está
    // disponible y, si no, cae a sed).
    function buildCommand() {
        var path = plasmoid.configuration.credentialsPath;
        if (!path || path.trim() === "") {
            path = "$HOME/.claude/.credentials.json";
        } else {
            path = path.replace(/^~(?=\/|$)/, "$HOME");
        }
        var p = '"' + path + '"';   // entre comillas dobles => $HOME se expande

        return 'TOKEN=$(jq -r \'.claudeAiOauth.accessToken\' ' + p + ' 2>/dev/null); ' +
               'if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then ' +
               'TOKEN=$(sed -n \'s/.*"accessToken"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p\' ' + p + ' | head -n1); fi; ' +
               'curl -s https://api.anthropic.com/api/oauth/usage ' +
               '-H "Authorization: Bearer $TOKEN" ' +
               '-H "anthropic-beta: oauth-2025-04-20" ' +
               '-H "User-Agent: claude-code/2.1.211" ' +
               '-H "Content-Type: application/json"';
    }

    function refresh() {
        root.loading = true;
        usageSource.exec(buildCommand());
    }

    function handleResult(stdout, stderr) {
        root.loading = false;
        var txt = (stdout || "").trim();
        if (txt.length === 0) {
            root.errorMsg = (stderr && stderr.trim().length)
                ? stderr.trim()
                : i18n("Sin respuesta. ¿Está 'curl' instalado y el token es válido?");
            return;
        }
        try {
            var obj = JSON.parse(txt);
            if (obj.error) {
                root.errorMsg = obj.error.message || i18n("Error de la API");
                return;
            }
            if (!obj.five_hour && !obj.seven_day) {
                root.errorMsg = i18n("Respuesta inesperada de la API");
                return;
            }
            root.usageData = obj;
            root.errorMsg = "";
            root.lastUpdate = Date.now();
        } catch (e) {
            root.errorMsg = i18n("No se pudo interpretar la respuesta: %1", e.toString());
        }
    }

    PlasmaCore.DataSource {
        id: usageSource
        engine: "executable"
        connectedSources: []

        onNewData: {
            var stdout = data["stdout"] || "";
            var stderr = data["stderr"] || "";
            disconnectSource(sourceName);   // permite re-ejecutar en el próximo refresh
            root.handleResult(stdout, stderr);
        }

        function exec(cmd) {
            connectSource(cmd);
        }
    }

    // Consulta periódica (por defecto cada 2 minutos)
    Timer {
        id: pollTimer
        interval: Math.max(15, plasmoid.configuration.refreshInterval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Reloj para actualizar el "tiempo restante" cada segundo
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // =====================================================================
    //  Representación compacta (panel) — modo minimalista: dos anillos
    //  escalables. Al pulsar se abre la representación completa.
    // =====================================================================
    Plasmoid.compactRepresentation: MouseArea {
        id: cr
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: {
            if (mouse.button === Qt.MiddleButton) {
                root.refresh();          // clic central: actualizar sin abrir el panel
            } else {
                plasmoid.expanded = !plasmoid.expanded;
            }
        }

        readonly property bool vertical: plasmoid.formFactor === PlasmaCore.Types.Vertical
        // Escala 50–100 % del grosor del panel. Al 100 % el anillo ocupa
        // (casi) todo el grosor, como los iconos vecinos.
        readonly property real scale01: Math.max(0.5, Math.min(1.0, plasmoid.configuration.panelIconScale / 100))
        readonly property real thickness: vertical ? cr.width : cr.height
        readonly property real ringSize: Math.round(Math.max(8, thickness * scale01))
        readonly property int gap: Kirigami.Units.smallSpacing

        // La altura la fija el panel; solo declaramos el ancho preferido.
        Layout.fillHeight: !vertical
        Layout.fillWidth: vertical
        Layout.preferredWidth:  vertical ? -1 : content.implicitWidth
        Layout.preferredHeight: vertical ? content.implicitHeight : -1
        Layout.minimumWidth: Layout.preferredWidth

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
                    Layout.preferredWidth: cr.ringSize
                    Layout.preferredHeight: cr.ringSize
                    value: root.utilOf("five_hour")
                    ringColor: plasmoid.configuration.ring5hColor
                    trackColor: plasmoid.configuration.ringTrackColor
                    thickness: Math.max(2, cr.ringSize * 0.15)
                    textColor: root.pctColor
                }
                Text {
                    text: root.resetLabel("five_hour", false)
                    color: root.txtColor
                    font.bold: true
                    font.pixelSize: Math.max(8, cr.ringSize * 0.30)
                }
            }

            // ---- Par 7d ----
            RowLayout {
                spacing: cr.gap
                RingChart {
                    Layout.preferredWidth: cr.ringSize
                    Layout.preferredHeight: cr.ringSize
                    value: root.utilOf("seven_day")
                    ringColor: plasmoid.configuration.ring7dColor
                    trackColor: plasmoid.configuration.ringTrackColor
                    thickness: Math.max(2, cr.ringSize * 0.15)
                    textColor: root.pctColor
                }
                Text {
                    text: root.resetLabel("seven_day", true)
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
    Plasmoid.fullRepresentation: Item {
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
                    text: i18n("Uso de Claude")
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

            // ---- Cuerpo: barras o anillos ----
            Loader {
                id: viewLoader
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

            // ---- Pie: error o última actualización ----
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
