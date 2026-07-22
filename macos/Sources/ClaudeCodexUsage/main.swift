import AppKit

// Punto de entrada. App de tipo "accesorio": vive solo en la barra de menús,
// sin icono en el Dock ni ventana principal.
//
// El arranque ocurre en el hilo principal (que es el ejecutor del MainActor),
// así que asumimos el aislamiento para poder crear el AppDelegate, que está
// aislado al MainActor. `app.run()` no retorna, por lo que `delegate` (referido
// de forma débil por NSApplication) se mantiene vivo dentro del cierre.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
