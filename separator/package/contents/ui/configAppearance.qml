import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: page

    property string cfg_lineColor
    property string cfg_pattern: "solid"
    property string cfg_orientation: "auto"
    property alias cfg_thickness: thicknessSpin.value
    property alias cfg_lengthPercent: lengthSlider.value
    property alias cfg_opacityPercent: opacitySlider.value
    property alias cfg_dashLength: dashSpin.value
    property alias cfg_gapLength: gapSpin.value

    // ---- Color ----
    RowLayout {
        Kirigami.FormData.label: i18n("Color:")
        ColorButton { currentColor: page.cfg_lineColor; onPicked: page.cfg_lineColor = hex }
        QQC2.Label { text: page.cfg_lineColor; opacity: 0.6 }
    }

    // ---- Patrón ----
    QQC2.ComboBox {
        id: patternCombo
        Kirigami.FormData.label: i18n("Patrón:")
        readonly property var values: ["solid", "dashed", "dotted"]
        model: [i18n("Sólido"), i18n("Discontinuo"), i18n("Punteado")]
        currentIndex: Math.max(0, values.indexOf(page.cfg_pattern))
        onActivated: page.cfg_pattern = values[currentIndex]
    }

    // ---- Orientación ----
    QQC2.ComboBox {
        id: orientationCombo
        Kirigami.FormData.label: i18n("Orientación:")
        readonly property var values: ["auto", "vertical", "horizontal"]
        model: [i18n("Automática (según el panel)"), i18n("Vertical"), i18n("Horizontal")]
        currentIndex: Math.max(0, values.indexOf(page.cfg_orientation))
        onActivated: page.cfg_orientation = values[currentIndex]
    }

    Item { Kirigami.FormData.isSection: true }

    // ---- Grosor ----
    QQC2.SpinBox {
        id: thicknessSpin
        Kirigami.FormData.label: i18n("Grosor:")
        from: 1
        to: 40
        editable: true
        textFromValue: function(v) { return v + " px"; }
        valueFromText: function(t) { var n = parseInt(t.replace(/[^0-9]/g, "")); return isNaN(n) ? thicknessSpin.value : n; }
    }

    // ---- Longitud (altura) ----
    RowLayout {
        Kirigami.FormData.label: i18n("Longitud:")
        QQC2.Slider {
            id: lengthSlider
            from: 5
            to: 100
            stepSize: 5
            snapMode: QQC2.Slider.SnapAlways
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label { text: Math.round(lengthSlider.value) + " %"; Layout.minimumWidth: Kirigami.Units.gridUnit * 3 }
    }

    // ---- Transparencia ----
    RowLayout {
        Kirigami.FormData.label: i18n("Opacidad:")
        QQC2.Slider {
            id: opacitySlider
            from: 0
            to: 100
            stepSize: 5
            snapMode: QQC2.Slider.SnapAlways
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label { text: Math.round(opacitySlider.value) + " %"; Layout.minimumWidth: Kirigami.Units.gridUnit * 3 }
    }

    Item { Kirigami.FormData.isSection: true }

    // ---- Trazo / hueco (sólo para discontinuo o punteado) ----
    QQC2.SpinBox {
        id: dashSpin
        Kirigami.FormData.label: i18n("Longitud del trazo:")
        from: 1
        to: 40
        editable: true
        enabled: page.cfg_pattern !== "solid"
        textFromValue: function(v) { return v + " px"; }
        valueFromText: function(t) { var n = parseInt(t.replace(/[^0-9]/g, "")); return isNaN(n) ? dashSpin.value : n; }
    }
    QQC2.SpinBox {
        id: gapSpin
        Kirigami.FormData.label: i18n("Separación:")
        from: 1
        to: 40
        editable: true
        enabled: page.cfg_pattern !== "solid"
        textFromValue: function(v) { return v + " px"; }
        valueFromText: function(t) { var n = parseInt(t.replace(/[^0-9]/g, "")); return isNaN(n) ? gapSpin.value : n; }
    }
}
