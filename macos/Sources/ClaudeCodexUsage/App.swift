import AppKit
import SwiftUI
import Combine

// =====================================================================
//  Delegado de la aplicación: crea los dos ítems de la barra de menús
//  (Claude y Codex), sus stores y la ventana de ajustes.
// =====================================================================

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let claudeSettings = ClaudeSettings()
    let codexSettings = CodexSettings()

    lazy var claudeStore = UsageStore<ClaudeUsage>(
        fetcher: { [claudeSettings] in
            try await ClaudeClient.fetch(credentialsPath: claudeSettings.credentialsPath)
        },
        intervalSeconds: { [claudeSettings] in claudeSettings.refreshInterval }
    )

    lazy var codexStore = UsageStore<CodexUsage>(
        fetcher: { [codexSettings] in
            try await CodexClient.fetch(credentialsPath: codexSettings.credentialsPath)
        },
        intervalSeconds: { [codexSettings] in codexSettings.refreshInterval }
    )

    let claudeFX = PanelFX()
    let codexFX = PanelFX()

    private var claudeController: StatusController?
    private var codexController: StatusController?
    private var settingsWindow: NSWindow?

    /// Activa/desactiva el ítem de Codex en la barra de menús.
    /// Momentáneamente desactivado: solo se muestra Claude.
    private let enableCodex = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ---- Claude ----
        claudeStore.onResult = { [claudeFX, claudeSettings] ok in
            claudeFX.onResult(success: ok, alarmEnabled: claudeSettings.errorBlink)
        }
        let claudeFull = NSHostingController(rootView: ClaudeFullView(
            store: claudeStore, settings: claudeSettings,
            onSettings: { [weak self] in self?.showSettings() }))
        claudeController = StatusController(
            makeCompact: { [claudeStore, claudeSettings, claudeFX] thickness in
                AnyView(ClaudeMenuBar(store: claudeStore, settings: claudeSettings, fx: claudeFX, thickness: thickness))
            },
            fullView: claudeFull,
            contentSize: NSSize(width: 300, height: 190),
            onRefresh: { [claudeStore] in claudeStore.refresh() },
            onSettings: { [weak self] in self?.showSettings() },
            changes: [
                claudeStore.objectWillChange.eraseToAnyPublisher(),
                claudeSettings.objectWillChange.eraseToAnyPublisher(),
                claudeFX.objectWillChange.eraseToAnyPublisher()
            ])

        // ---- Codex (desactivado temporalmente; poner enableCodex = true) ----
        guard enableCodex else { return }
        codexStore.onResult = { [codexFX, codexSettings] ok in
            codexFX.onResult(success: ok, alarmEnabled: codexSettings.errorBlink)
        }
        let codexFull = NSHostingController(rootView: CodexFullView(
            store: codexStore, settings: codexSettings,
            onSettings: { [weak self] in self?.showSettings() }))
        codexController = StatusController(
            makeCompact: { [codexStore, codexSettings, codexFX] thickness in
                AnyView(CodexMenuBar(store: codexStore, settings: codexSettings, fx: codexFX, thickness: thickness))
            },
            fullView: codexFull,
            contentSize: NSSize(width: 300, height: 160),
            onRefresh: { [codexStore] in codexStore.refresh() },
            onSettings: { [weak self] in self?.showSettings() },
            changes: [
                codexStore.objectWillChange.eraseToAnyPublisher(),
                codexSettings.objectWillChange.eraseToAnyPublisher(),
                codexFX.objectWillChange.eraseToAnyPublisher()
            ])
    }

    func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(claude: claudeSettings, codex: codexSettings))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Ajustes — Uso de Claude / Codex"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
