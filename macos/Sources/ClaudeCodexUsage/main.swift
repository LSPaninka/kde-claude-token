import AppKit

// Punto de entrada. App de tipo "accesorio": vive solo en la barra de menús,
// sin icono en el Dock ni ventana principal.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
