import Foundation
import Combine

// =====================================================================
//  Store: ciclo de actualización + reloj (§7 y §8 de SPEC.md)
//
//  Subsistema común a ambos widgets:
//    - Temporizador de sondeo (intervalo configurable, se dispara al arrancar).
//    - Reloj de 1 s que solo recalcula el "tiempo restante" mostrado.
//    - Máquina de estados IDLE → LOADING → READY/ERROR → IDLE.
//    - El estado ERROR NO borra los últimos datos válidos.
// =====================================================================

@MainActor
final class UsageStore<Value: Equatable>: ObservableObject {

    @Published private(set) var value: Value?
    @Published private(set) var errorMsg: String = ""
    @Published private(set) var loading: Bool = false
    @Published private(set) var lastUpdate: Date?
    /// Instante actual, refrescado cada segundo para recalcular tiempos restantes.
    @Published private(set) var now: Date = Date()

    private let fetcher: () async throws -> Value
    private let intervalSeconds: () -> Int

    private var pollTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?

    init(fetcher: @escaping () async throws -> Value,
         intervalSeconds: @escaping () -> Int) {
        self.fetcher = fetcher
        self.intervalSeconds = intervalSeconds
        start()
    }

    private func start() {
        // Reloj de 1 s (solo actualiza `now`; no hace red).
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { self?.now = Date() }
            }
        }
        // Bucle de sondeo (se dispara también al arrancar).
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.fetchNow()
                let secs = max(15, self.intervalSeconds())
                try? await Task.sleep(nanoseconds: UInt64(secs) * 1_000_000_000)
            }
        }
    }

    /// Fuerza una obtención inmediata (botón Actualizar / clic central).
    func refresh() {
        Task { await fetchNow() }
    }

    private func fetchNow() async {
        loading = true
        defer { loading = false }
        do {
            let v = try await fetcher()
            value = v
            errorMsg = ""
            lastUpdate = Date()
        } catch {
            // ERROR: conservamos los últimos datos válidos y mostramos el mensaje.
            errorMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    deinit {
        pollTask?.cancel()
        clockTask?.cancel()
    }
}
