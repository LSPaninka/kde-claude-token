import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // Claves de color (cadenas hex #AARRGGBB) y opciones
    property string cfg_bar5hColor
    property string cfg_bar7dColor
    property string cfg_barTrackColor
    property string cfg_ring5hColor
    property string cfg_ring7dColor
    property string cfg_ringTrackColor
    property string cfg_labelColor
    property string cfg_percentColor
    property alias cfg_ringThickness: thicknessSpin.value
    property alias cfg_useThemeTextColor: themeTextCheck.checked

    Kirigami.FormLayout {
        // ============ Barras ============
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Barras")
            Kirigami.FormData.isSection: true
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Barra 5h:")
            ColorButton { currentColor: page.cfg_bar5hColor; onPicked: (hex) => page.cfg_bar5hColor = hex }
            QQC2.Label { text: page.cfg_bar5hColor; opacity: 0.6 }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Barra semanal:")
            ColorButton { currentColor: page.cfg_bar7dColor; onPicked: (hex) => page.cfg_bar7dColor = hex }
            QQC2.Label { text: page.cfg_bar7dColor; opacity: 0.6 }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Fondo de barra:")
            ColorButton { currentColor: page.cfg_barTrackColor; onPicked: (hex) => page.cfg_barTrackColor = hex }
            QQC2.Label { text: page.cfg_barTrackColor; opacity: 0.6 }
        }

        // ============ Anillos ============
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Anillos")
            Kirigami.FormData.isSection: true
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Anillo 5h:")
            ColorButton { currentColor: page.cfg_ring5hColor; onPicked: (hex) => page.cfg_ring5hColor = hex }
            QQC2.Label { text: page.cfg_ring5hColor; opacity: 0.6 }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Anillo semanal:")
            ColorButton { currentColor: page.cfg_ring7dColor; onPicked: (hex) => page.cfg_ring7dColor = hex }
            QQC2.Label { text: page.cfg_ring7dColor; opacity: 0.6 }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Fondo de anillo:")
            ColorButton { currentColor: page.cfg_ringTrackColor; onPicked: (hex) => page.cfg_ringTrackColor = hex }
            QQC2.Label { text: page.cfg_ringTrackColor; opacity: 0.6 }
        }
        QQC2.SpinBox {
            id: thicknessSpin
            Kirigami.FormData.label: i18n("Grosor del anillo:")
            from: 2
            to: 40
            editable: true
        }

        // ============ Texto ============
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Texto")
            Kirigami.FormData.isSection: true
        }
        QQC2.CheckBox {
            id: themeTextCheck
            Kirigami.FormData.label: i18n("Color del texto:")
            text: i18n("Usar el color del tema")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Color de etiquetas:")
            enabled: !themeTextCheck.checked
            ColorButton { currentColor: page.cfg_labelColor; onPicked: (hex) => page.cfg_labelColor = hex }
            QQC2.Label { text: page.cfg_labelColor; opacity: 0.6 }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Color del porcentaje:")
            enabled: !themeTextCheck.checked
            ColorButton { currentColor: page.cfg_percentColor; onPicked: (hex) => page.cfg_percentColor = hex }
            QQC2.Label { text: page.cfg_percentColor; opacity: 0.6 }
        }
    }
}
