import Foundation
import SwiftUI
import Combine

// =====================================================================
//  Efectos del panel (anillos de la barra de menús)
//
//  Port de los commits del plasmoide:
//   - Destello al actualizar: éxito = arco verde + fondo verde oscuro;
//     fallo = arco rojo. Sube en 150 ms (OutQuad) y baja en 550 ms (InQuad).
//   - Alarma tras 2 errores seguidos: titileo continuo (700 ms InOutSine en
//     bucle) del fondo hacia rojo oscuro y del arco hacia rojo brillante.
//
//  A diferencia del QML (canvas vivo), aquí el icono es una NSImage que se
//  redibuja; por eso un timer avanza el progreso y publica cambios (solo mientras
//  haya destello o alarma activos) para que el StatusController rerenderice.
// =====================================================================

@MainActor
final class PanelFX: ObservableObject {

    // Colores del efecto (idénticos al QML).
    static let successArc = Color(hex: "#00e676")   // verde brillante
    static let successTrack = Color(hex: "#006400") // verde oscuro
    static let failArc = Color(hex: "#ff1744")      // rojo brillante
    static let alarmArc = Color(hex: "#ff1744")     // rojo brillante (arco)
    static let alarmTrack = Color(hex: "#8b0000")   // rojo oscuro (fondo)

    /// Se incrementa en cada frame para forzar el rerender del icono.
    @Published private(set) var tick: Int = 0

    // Estado leído por la vista compacta (no @Published: la vista se reconstruye
    // en cada rerender disparado por `tick`).
    private(set) var flashProgress: Double = 0
    private(set) var flashSuccess: Bool = true
    private(set) var alarmProgress: Double = 0
    private(set) var failStreak: Int = 0

    private var alarmEnabled: Bool = false
    var alarmActive: Bool { alarmEnabled && failStreak >= 2 }

    private var flashStart: Date?
    private var alarmStart: Date?
    private var timer: Timer?

    /// Llamar al terminar cada obtención de datos.
    func onResult(success: Bool, alarmEnabled: Bool) {
        self.alarmEnabled = alarmEnabled
        failStreak = success ? 0 : failStreak + 1
        flashSuccess = success
        flashStart = Date()
        if !alarmActive { alarmStart = nil; alarmProgress = 0 }
        ensureTimer()
        update()
    }

    private func ensureTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        RunLoop.main.add(t, forMode: .common)   // sigue animando con menús/popovers abiertos
        timer = t
    }

    private func update() {
        let now = Date()

        // ---- Destello ----
        if let start = flashStart {
            let t = now.timeIntervalSince(start)
            if t >= 0.70 {
                flashProgress = 0
                flashStart = nil
            } else if t < 0.15 {
                flashProgress = Ease.outQuad(t / 0.15)               // 0 -> 1
            } else {
                flashProgress = 1 - Ease.inQuad((t - 0.15) / 0.55)   // 1 -> 0
            }
        }

        // ---- Alarma (bucle continuo mientras esté activa) ----
        if alarmActive {
            if alarmStart == nil { alarmStart = now }
            let t = now.timeIntervalSince(alarmStart!)
            let phase = t.truncatingRemainder(dividingBy: 1.4) / 1.4  // 0..1 (periodo 1.4 s)
            alarmProgress = phase < 0.5
                ? Ease.inOutSine(phase / 0.5)                        // 0 -> 1
                : 1 - Ease.inOutSine((phase - 0.5) / 0.5)            // 1 -> 0
        } else {
            alarmStart = nil
            alarmProgress = 0
        }

        // Detener el timer si no queda nada que animar.
        if flashStart == nil && !alarmActive {
            timer?.invalidate()
            timer = nil
        }

        tick &+= 1   // dispara objectWillChange -> rerender del icono
    }

    // Color efectivo del arco: base (con alarma) + destello encima.
    func arcColor(_ ringColor: Color) -> Color {
        let base = alarmActive ? mixColors(ringColor, Self.alarmArc, alarmProgress) : ringColor
        guard flashProgress > 0 else { return base }
        return mixColors(base, flashSuccess ? Self.successArc : Self.failArc, flashProgress)
    }

    // Color efectivo del fondo/pista: base (con alarma) + destello SOLO en éxito.
    func trackColor(_ trackColor: Color) -> Color {
        let base = alarmActive ? mixColors(trackColor, Self.alarmTrack, alarmProgress) : trackColor
        guard flashProgress > 0 && flashSuccess else { return base }
        return mixColors(base, Self.successTrack, flashProgress)
    }
}

private enum Ease {
    static func outQuad(_ p: Double) -> Double { 1 - (1 - p) * (1 - p) }
    static func inQuad(_ p: Double) -> Double { p * p }
    static func inOutSine(_ p: Double) -> Double { (1 - cos(.pi * p)) / 2 }
}
