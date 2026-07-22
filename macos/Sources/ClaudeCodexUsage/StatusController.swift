import AppKit
import SwiftUI
import Combine

// =====================================================================
//  Controlador de un ítem de la barra de menús (§7 y §12 de SPEC.md)
//
//  La vista compacta se dibuja a una NSImage (con color) y se coloca como
//  `button.image` del NSStatusItem. Es el montaje "vanilla" de las apps de barra
//  de menús: la ALTURA del botón la controla el sistema (la de la barra), por lo
//  que el popover se ancla pegado a la barra, sin huecos.
//
//  Gestos:
//   - Clic izquierdo → abrir/cerrar el popover con la vista completa.
//   - Clic central   → actualizar de inmediato (sin abrir el popover).
//   - Clic derecho   → menú contextual (Actualizar / Ajustes / Salir).
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
         contentSize: NSSize,
         onRefresh: @escaping () -> Void,
         onSettings: @escaping () -> Void,
         changes: [AnyPublisher<Void, Never>]) {
        self.makeCompact = makeCompact
        self.onRefresh = onRefresh
        self.onSettings = onSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Tamaño FIJO del popover: evita que NSPopover recalcule su tamaño desde
        // el contenido y se desfase al refrescar. Sin animación por el mismo motivo.
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = contentSize
        popover.contentViewController = fullView

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp, .otherMouseUp])
        }

        renderImage()

        // Redibuja el icono al cambiar datos/config o el tema claro/oscuro.
        for publisher in changes {
            publisher
                .receive(on: RunLoop.main)
                .sink { [weak self] in MainActor.assumeIsolated { self?.renderImage() } }
                .store(in: &cancellables)
        }
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.renderImage() } }
            .store(in: &cancellables)
    }

    /// Renderiza la vista compacta a una imagen y la coloca en el botón del ítem.
    private func renderImage() {
        guard let button = statusItem.button else { return }
        let height = NSStatusBar.system.thickness
        let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        let content = makeCompact(height)
            .environment(\.colorScheme, isDark ? .dark : .light)

        let renderer = ImageRenderer(content: content)
        renderer.scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        if let image = renderer.nsImage {
            image.isTemplate = false          // conservamos el color de los anillos
            button.image = image
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
            return
        }
        // Anclar al botón del ítem (borde inferior), pegado a la barra de menús.
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
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
