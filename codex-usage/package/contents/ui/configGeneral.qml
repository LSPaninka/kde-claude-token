import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_credentialsPath: pathField.text
    property alias cfg_showRemaining: remainingCheck.checked
    property alias cfg_panelIconScale: scaleSlider.value
    property alias cfg_errorBlink: errorBlinkCheck.checked
    property string cfg_displayMode: "bars"

    // ---- Intervalo de consulta ----
    RowLayout {
        Kirigami.FormData.label: i18n("Consultar cada:")
        QQC2.SpinBox {
            id: intervalSpin
            from: 15
            to: 86400
            stepSize: 15
            editable: true
            textFromValue: function(value) {
                if (value % 60 === 0) return (value / 60) + " min";
                return value + " s";
            }
            valueFromText: function(text) {
                var t = text.toLowerCase().trim();
                var n = parseInt(t.replace(/[^0-9]/g, ""));
                if (isNaN(n)) return intervalSpin.value;
                return t.indexOf("min") >= 0 ? n * 60 : n;
            }
        }
        QQC2.Label { text: i18n("(por defecto: 2 min)"); opacity: 0.7 }
    }

    Item { Kirigami.FormData.isSection: true }

    // ---- Modo de visualización ----
    QQC2.ComboBox {
        id: modeCombo
        Kirigami.FormData.label: i18n("Modo de visualización:")
        readonly property var values: ["bars", "rings"]
        model: [i18n("Barra (completo)"), i18n("Anillo (minimalista)")]
        currentIndex: Math.max(0, values.indexOf(page.cfg_displayMode))
        onActivated: page.cfg_displayMode = values[currentIndex]
    }

    QQC2.CheckBox {
        id: remainingCheck
        Kirigami.FormData.label: i18n("Etiquetas:")
        text: i18n("Mostrar el tiempo restante (modo barra)")
    }

    Item { Kirigami.FormData.isSection: true }

    // ---- Modo minimalista en el panel ----
    RowLayout {
        Kirigami.FormData.label: i18n("Escala del anillo (panel):")
        QQC2.Slider {
            id: scaleSlider
            from: 50
            to: 100
            stepSize: 5
            snapMode: QQC2.Slider.SnapAlways
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label {
            text: Math.round(scaleSlider.value) + " %"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
        }
    }
    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        text: i18n("Tamaño del anillo cuando el plasmoide está en un panel. Clic izquierdo abre la vista completa; clic central actualiza.")
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
    }

    QQC2.CheckBox {
        id: errorBlinkCheck
        Kirigami.FormData.label: i18n("Errores:")
        text: i18n("Titilar el fondo del anillo en rojo tras 2 errores seguidos")
    }

    Item { Kirigami.FormData.isSection: true }

    // ---- Credenciales ----
    QQC2.TextField {
        id: pathField
        Kirigami.FormData.label: i18n("Archivo de credenciales:")
        Layout.fillWidth: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        placeholderText: "~/.codex/auth.json"
    }
    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        text: i18n("Déjalo vacío para usar ${CODEX_HOME:-~/.codex}/auth.json. Se leen access_token y account_id y se consulta https://chatgpt.com/backend-api/wham/usage.")
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
    }
}
