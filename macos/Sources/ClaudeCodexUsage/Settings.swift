import SwiftUI
import Combine

// =====================================================================
//  Configuración persistente (§5 de SPEC.md)
//
//  Cada widget tiene su propia configuración, guardada en UserDefaults con
//  las mismas claves, tipos y valores por defecto que el KConfig de KDE.
//  Los colores se guardan como cadenas hexadecimales #AARRGGBB.
// =====================================================================

private let defaults = UserDefaults.standard

private func loadString(_ key: String, _ fallback: String) -> String {
    defaults.string(forKey: key) ?? fallback
}
private func loadInt(_ key: String, _ fallback: Int) -> Int {
    defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
}
private func loadBool(_ key: String, _ fallback: Bool) -> Bool {
    defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
}

/// Configuración del widget "Uso de Claude".
final class ClaudeSettings: ObservableObject {

    // ---- General ----
    @Published var refreshInterval: Int   { didSet { defaults.set(refreshInterval, forKey: "claude.refreshInterval") } }
    @Published var credentialsPath: String { didSet { defaults.set(credentialsPath, forKey: "claude.credentialsPath") } }
    @Published var displayMode: String     { didSet { defaults.set(displayMode, forKey: "claude.displayMode") } }
    @Published var showRemaining: Bool      { didSet { defaults.set(showRemaining, forKey: "claude.showRemaining") } }
    @Published var panelIconScale: Int      { didSet { defaults.set(panelIconScale, forKey: "claude.panelIconScale") } }
    @Published var errorBlink: Bool         { didSet { defaults.set(errorBlink, forKey: "claude.errorBlink") } }

    // ---- Apariencia ----
    @Published var bar5hColor: String       { didSet { defaults.set(bar5hColor, forKey: "claude.bar5hColor") } }
    @Published var bar7dColor: String       { didSet { defaults.set(bar7dColor, forKey: "claude.bar7dColor") } }
    @Published var barTrackColor: String    { didSet { defaults.set(barTrackColor, forKey: "claude.barTrackColor") } }
    @Published var ring5hColor: String      { didSet { defaults.set(ring5hColor, forKey: "claude.ring5hColor") } }
    @Published var ring7dColor: String      { didSet { defaults.set(ring7dColor, forKey: "claude.ring7dColor") } }
    @Published var ringTrackColor: String   { didSet { defaults.set(ringTrackColor, forKey: "claude.ringTrackColor") } }
    @Published var ringThickness: Int       { didSet { defaults.set(ringThickness, forKey: "claude.ringThickness") } }
    @Published var labelColor: String       { didSet { defaults.set(labelColor, forKey: "claude.labelColor") } }
    @Published var percentColor: String     { didSet { defaults.set(percentColor, forKey: "claude.percentColor") } }
    @Published var useThemeTextColor: Bool  { didSet { defaults.set(useThemeTextColor, forKey: "claude.useThemeTextColor") } }

    init() {
        refreshInterval   = loadInt("claude.refreshInterval", 120)
        credentialsPath   = loadString("claude.credentialsPath", "")
        displayMode       = loadString("claude.displayMode", "bars")
        showRemaining     = loadBool("claude.showRemaining", true)
        panelIconScale    = loadInt("claude.panelIconScale", 100)
        errorBlink        = loadBool("claude.errorBlink", true)
        bar5hColor        = loadString("claude.bar5hColor", "#ffcc785c")
        bar7dColor        = loadString("claude.bar7dColor", "#ff7c5cff")
        barTrackColor     = loadString("claude.barTrackColor", "#40808080")
        ring5hColor       = loadString("claude.ring5hColor", "#ffcc785c")
        ring7dColor       = loadString("claude.ring7dColor", "#ff7c5cff")
        ringTrackColor    = loadString("claude.ringTrackColor", "#40808080")
        ringThickness     = loadInt("claude.ringThickness", 12)
        labelColor        = loadString("claude.labelColor", "#ffffffff")
        percentColor      = loadString("claude.percentColor", "#ffffffff")
        useThemeTextColor = loadBool("claude.useThemeTextColor", true)
    }

    var txtColor: Color { useThemeTextColor ? .primary : Color(hex: labelColor) }
    var pctColor: Color { useThemeTextColor ? .primary : Color(hex: percentColor) }
}

/// Configuración del widget "Uso de Codex".
final class CodexSettings: ObservableObject {

    // ---- General ----
    @Published var refreshInterval: Int   { didSet { defaults.set(refreshInterval, forKey: "codex.refreshInterval") } }
    @Published var credentialsPath: String { didSet { defaults.set(credentialsPath, forKey: "codex.credentialsPath") } }
    @Published var displayMode: String     { didSet { defaults.set(displayMode, forKey: "codex.displayMode") } }
    @Published var showRemaining: Bool      { didSet { defaults.set(showRemaining, forKey: "codex.showRemaining") } }
    @Published var panelIconScale: Int      { didSet { defaults.set(panelIconScale, forKey: "codex.panelIconScale") } }
    @Published var errorBlink: Bool         { didSet { defaults.set(errorBlink, forKey: "codex.errorBlink") } }

    // ---- Apariencia (un solo límite → un solo color de acento) ----
    @Published var barColor: String         { didSet { defaults.set(barColor, forKey: "codex.barColor") } }
    @Published var barTrackColor: String    { didSet { defaults.set(barTrackColor, forKey: "codex.barTrackColor") } }
    @Published var ringColor: String        { didSet { defaults.set(ringColor, forKey: "codex.ringColor") } }
    @Published var ringTrackColor: String   { didSet { defaults.set(ringTrackColor, forKey: "codex.ringTrackColor") } }
    @Published var ringThickness: Int       { didSet { defaults.set(ringThickness, forKey: "codex.ringThickness") } }
    @Published var labelColor: String       { didSet { defaults.set(labelColor, forKey: "codex.labelColor") } }
    @Published var percentColor: String     { didSet { defaults.set(percentColor, forKey: "codex.percentColor") } }
    @Published var useThemeTextColor: Bool  { didSet { defaults.set(useThemeTextColor, forKey: "codex.useThemeTextColor") } }

    init() {
        refreshInterval   = loadInt("codex.refreshInterval", 120)
        credentialsPath   = loadString("codex.credentialsPath", "")
        displayMode       = loadString("codex.displayMode", "bars")
        showRemaining     = loadBool("codex.showRemaining", true)
        panelIconScale    = loadInt("codex.panelIconScale", 100)
        errorBlink        = loadBool("codex.errorBlink", true)
        barColor          = loadString("codex.barColor", "#ff10a37f")
        barTrackColor     = loadString("codex.barTrackColor", "#40808080")
        ringColor         = loadString("codex.ringColor", "#ff10a37f")
        ringTrackColor    = loadString("codex.ringTrackColor", "#40808080")
        ringThickness     = loadInt("codex.ringThickness", 12)
        labelColor        = loadString("codex.labelColor", "#ffffffff")
        percentColor      = loadString("codex.percentColor", "#ffffffff")
        useThemeTextColor = loadBool("codex.useThemeTextColor", true)
    }

    var txtColor: Color { useThemeTextColor ? .primary : Color(hex: labelColor) }
    var pctColor: Color { useThemeTextColor ? .primary : Color(hex: percentColor) }
}
