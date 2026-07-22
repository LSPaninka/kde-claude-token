import AppKit
import SwiftUI
import Combine

// =====================================================================
//  Controlador de un ítem de la barra de menús (§7 y §12 de SPEC.md)
//
//  La vista compacta (SwiftUI) se hospeda DIRECTAMENTE en el botón del ítem con
//  un NSHostingView, en lugar de renderizarla a una imagen. Ventajas:
//   - El frame del botón coincide exactamente con lo visible (sin padding ni
//     escalado extra), así el popover queda pegado a la barra de menús.
//   - El color se adapta solo a claro/oscuro del sistema.
//   - El contenido se refresca solo al cambiar los datos/config (SwiftUI).
//
//  Gestos:
//   - Clic izquierdo → abrir/cerrar el popover con la vista completa.
//   - Clic central   → actualizar de inmediato (sin abrir el popover).
//   - Clic derecho   → menú contextual (Actualizar / Ajustes / Salir).
// =====================================================================

/// NSHostingView que deja pasar los clics al botón padre (no los intercepta),
/// para que el `target/action` del NSStatusItem siga funcionando.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class StatusController {

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let hostingView: ClickThroughHostingView<AnyView>
    private let onRefresh: () -> Void
    private let onSettings: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(makeCompact: @escaping (CGFloat) -> AnyView,
         fullView: NSViewController,
         onRefresh: @escaping () -> Void,
         onSettings: @escaping () -> Void,
         changes: [AnyPublisher<Void, Never>]) {
        self.onRefresh = onRefresh
        self.onSettings = onSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let thickness = NSStatusBar.system.thickness
        self.hostingView = ClickThroughHostingView(rootView: makeCompact(thickness))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = fullView

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp, .otherMouseUp])

            button.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: button.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor)
            ])
        }

        updateLength()

        // Al cambiar datos/config, el ancho del contenido puede variar; el
        // contenido SwiftUI se actualiza solo, solo reajustamos la longitud.
        for publisher in changes {
            publisher
                .receive(on: RunLoop.main)
                .sink { [weak self] in
                    MainActor.assumeIsolated { self?.updateLength() }
                }
                .store(in: &cancellables)
        }
    }

    /// Ajusta el ancho del ítem al ancho intrínseco del contenido.
    private func updateLength() {
        hostingView.layoutSubtreeIfNeeded()
        let width = hostingView.fittingSize.width
        statusItem.length = width > 1 ? width : 40
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
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
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
