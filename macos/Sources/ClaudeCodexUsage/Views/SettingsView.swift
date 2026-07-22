import SwiftUI

// =====================================================================
//  Ventana de ajustes (§5 de SPEC.md)
// =====================================================================

/// Crea un `Binding<Color>` a partir de un binding a la cadena hex #AARRGGBB.
private func colorBinding(_ hex: Binding<String>) -> Binding<Color> {
    Binding(
        get: { Color(hex: hex.wrappedValue) },
        set: { hex.wrappedValue = $0.hexAARRGGBB }
    )
}

private let displayModes = ["bars": "Barras", "rings": "Anillos"]

struct SettingsView: View {
    @ObservedObject var claude: ClaudeSettings
    @ObservedObject var codex: CodexSettings

    var body: some View {
        TabView {
            ClaudeSettingsTab(s: claude)
                .tabItem { Text("Claude") }
            CodexSettingsTab(s: codex)
                .tabItem { Text("Codex") }
        }
        .padding(16)
        .frame(width: 460, height: 520)
    }
}

// ---- General reutilizable ----

private struct GeneralSection: View {
    @Binding var refreshInterval: Int
    @Binding var credentialsPath: String
    @Binding var displayMode: String
    @Binding var showRemaining: Bool
    @Binding var panelIconScale: Int
    var credentialsPlaceholder: String

    var body: some View {
        Section("General") {
            Stepper(value: $refreshInterval, in: 15...86400, step: 15) {
                Text("Intervalo de sondeo: \(refreshInterval) s")
            }
            HStack {
                Text("Credenciales")
                TextField(credentialsPlaceholder, text: $credentialsPath)
                    .textFieldStyle(.roundedBorder)
            }
            Picker("Vista completa", selection: $displayMode) {
                Text("Barras").tag("bars")
                Text("Anillos").tag("rings")
            }
            Toggle("Mostrar tiempo restante (modo barras)", isOn: $showRemaining)
            Stepper(value: $panelIconScale, in: 50...100, step: 5) {
                Text("Tamaño en la barra: \(panelIconScale) %")
            }
        }
    }
}

// ---- Claude ----

private struct ClaudeSettingsTab: View {
    @ObservedObject var s: ClaudeSettings

    var body: some View {
        Form {
            GeneralSection(
                refreshInterval: $s.refreshInterval,
                credentialsPath: $s.credentialsPath,
                displayMode: $s.displayMode,
                showRemaining: $s.showRemaining,
                panelIconScale: $s.panelIconScale,
                credentialsPlaceholder: "Keychain de macOS (o ruta a .credentials.json)")

            Section("Colores") {
                Toggle("Usar el color de texto del tema", isOn: $s.useThemeTextColor)
                ColorPicker("Barra 5 h", selection: colorBinding($s.bar5hColor))
                ColorPicker("Barra semanal", selection: colorBinding($s.bar7dColor))
                ColorPicker("Fondo de barras", selection: colorBinding($s.barTrackColor))
                ColorPicker("Anillo 5 h", selection: colorBinding($s.ring5hColor))
                ColorPicker("Anillo semanal", selection: colorBinding($s.ring7dColor))
                ColorPicker("Fondo de anillos", selection: colorBinding($s.ringTrackColor))
                Stepper(value: $s.ringThickness, in: 2...40) {
                    Text("Grosor del anillo: \(s.ringThickness)")
                }
                if !s.useThemeTextColor {
                    ColorPicker("Etiquetas", selection: colorBinding($s.labelColor))
                    ColorPicker("Porcentaje", selection: colorBinding($s.percentColor))
                }
            }
        }
        .formStyle(.grouped)
    }
}

// ---- Codex ----

private struct CodexSettingsTab: View {
    @ObservedObject var s: CodexSettings

    var body: some View {
        Form {
            GeneralSection(
                refreshInterval: $s.refreshInterval,
                credentialsPath: $s.credentialsPath,
                displayMode: $s.displayMode,
                showRemaining: $s.showRemaining,
                panelIconScale: $s.panelIconScale,
                credentialsPlaceholder: "${CODEX_HOME:-~/.codex}/auth.json")

            Section("Colores") {
                Toggle("Usar el color de texto del tema", isOn: $s.useThemeTextColor)
                ColorPicker("Barra", selection: colorBinding($s.barColor))
                ColorPicker("Fondo de barra", selection: colorBinding($s.barTrackColor))
                ColorPicker("Anillo", selection: colorBinding($s.ringColor))
                ColorPicker("Fondo de anillo", selection: colorBinding($s.ringTrackColor))
                Stepper(value: $s.ringThickness, in: 2...40) {
                    Text("Grosor del anillo: \(s.ringThickness)")
                }
                if !s.useThemeTextColor {
                    ColorPicker("Etiquetas", selection: colorBinding($s.labelColor))
                    ColorPicker("Porcentaje", selection: colorBinding($s.percentColor))
                }
            }
        }
        .formStyle(.grouped)
    }
}
