// swift-tools-version: 6.0
import PackageDescription

// App nativo para macOS 26 (Tahoe) que reimplementa los plasmoides de KDE
// "Uso de Claude" y "Uso de Codex" como iconos de la barra de menús.
//
// - La versión minimalista (anillos + hora de reinicio) vive en la barra de
//   menús (NSStatusItem).
// - La versión completa (barras/anillos con detalle) se abre al hacer clic
//   (NSPopover).
//
// Compilar/ejecutar:  cd macos && swift run
let package = Package(
    name: "ClaudeCodexUsage",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCodexUsage",
            path: "Sources/ClaudeCodexUsage",
            swiftSettings: [
                // Mantener el modo de lenguaje Swift 5 para una concurrencia
                // menos estricta (los temporizadores y stores viven en el
                // MainActor); simplifica el port sin sacrificar corrección.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
