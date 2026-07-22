import AppKit
import SwiftUI
import Combine

// =====================================================================
//  Controlador de un ítem de la barra de menús (§7 y §12 de SPEC.md)
//
//  - La representación compacta se renderiza a una NSImage (con color) que se
//    coloca en el NSStatusItem; se re-renderiza cuando cambian los datos, la
//    configuración o la apariencia clara/oscura del sistema.
//  - Clic izquierdo   → abrir/cerrar el popover con la vista completa.
//  - Clic central     → actualizar de inmediato (sin abrir el popover).
//  - Clic derecho     → menú contextual (Actualizar / Ajustes / Salir).
// =====================================================================

@MainActor
final class StatusController {

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let makeCompact: (CGFloat) -> AnyView
    private let onRefresh: () -> Void
    private let onSettings: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(makeCompact: @escaping (CGFloat) -> AnyView,
         fullView: NSViewController,
         onRefresh: @escaping () -> Void,
         onSettings: @escaping () -> Void,
         changes: [AnyPublisher<Void, Never>]) {
        self.makeCompact = makeCompact
        self.onRefresh = onRefresh
        self.onSettings = onSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = fullView

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp, .otherMouseUp])
        }

        // Re-render cuando cambian datos o configuración (en el siguiente ciclo
        // del runloop, para leer ya el valor nuevo, no el `willChange`).
        for publisher in changes {
            publisher
                .receive(on: RunLoop.main)
                .sink { [weak self] in
                    MainActor.assumeIsolated { self?.render() }
                }
                .store(in: &cancellables)
        }

        // Re-render al cambiar el tema claro/oscuro del sistema.
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.render() }
            }
            .store(in: &cancellables)

        render()
    }

    /// Renderiza la vista compacta a una imagen y la coloca en el ítem.
    func render() {
        guard let button = statusItem.button else { return }
        let thickness = NSStatusBar.system.thickness
        let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        let content = makeCompact(thickness)
            .environment(\.colorScheme, isDark ? .dark : .light)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        if let image = renderer.nsImage {
            image.isTemplate = false          // conservamos el color de los anillos
            button.image = image
            button.imagePosition = .imageOnly
        }
    }

    // ---- Interacción ----

    @objc private func handleClick(_ sender: Any?) {
        let type = NSApp.currentEvent?.type
        if type == .rightMouseUp {
            showMenu()
        } else if type == .otherMouseUp {      // clic central
            onRefresh()
        } else {                               // clic izquierdo
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        addItem(to: menu, title: "Actualizar", action: #selector(menuRefresh))
        addItem(to: menu, title: "Ajustes…", action: #selector(menuSettings), key: ",")
        menu.addItem(.separator())
        addItem(to: menu, title: "Salir", action: #selector(menuQuit), key: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)   // muestra el menú anclado al ítem
        statusItem.menu = nil                   // restaura el comportamiento de clic
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector, key: String = "") {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
    }

    @objc private func menuRefresh() { onRefresh() }
    @objc private func menuSettings() { onSettings() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
}
