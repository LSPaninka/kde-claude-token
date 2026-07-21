import Foundation

/// Utilidades puras de formato — port 1:1 de `lib/format.js` de los plasmoides.
///
/// Todas las horas se muestran en **hora local** del sistema, 24 h, con cero a
/// la izquierda. Los nombres de día abreviados están **en español** y forman
/// parte de la especificación (formato `ddd`).
enum Fmt {

    /// Abreviaturas de los días en español.
    /// El índice sigue la convención de `Date.getDay()`: 0 = domingo … 6 = sábado.
    static let dias = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]

    /// Entero con cero a la izquierda a 2 dígitos.
    static func two(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }

    private static var calendar: Calendar { Calendar.current }

    /// "hh:mm" en hora local.
    static func fmtHM(_ d: Date?) -> String {
        guard let d else { return "--:--" }
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return two(c.hour ?? 0) + ":" + two(c.minute ?? 0)
    }

    /// "ddd hh:mm" (ddd = tres primeras letras del día en español).
    static func fmtDddHM(_ d: Date?) -> String {
        guard let d else { return "--- --:--" }
        // `Calendar.component(.weekday)` devuelve 1 = domingo … 7 = sábado
        // (calendario gregoriano). Reindexamos a 0…6 para `dias`.
        let weekday = calendar.component(.weekday, from: d) - 1
        let idx = (weekday % 7 + 7) % 7
        return dias[idx] + " " + fmtHM(d)
    }

    /// "dd/mm hh:mm".
    static func fmtFull(_ d: Date?) -> String {
        guard let d else { return "--/-- --:--" }
        let c = calendar.dateComponents([.day, .month], from: d)
        return two(c.day ?? 0) + "/" + two(c.month ?? 0) + " " + fmtHM(d)
    }

    /// Tiempo restante legible a partir de milisegundos: "1d 4h", "3h 12m", "8m".
    /// Entradas inválidas o <= 0 devuelven "0m".
    static func fmtRemaining(_ ms: Double) -> String {
        if ms.isNaN || ms <= 0 { return "0m" }
        var s = Int((ms / 1000).rounded(.down))
        let d = s / 86400; s -= d * 86400
        let h = s / 3600;  s -= h * 3600
        let m = s / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// Etiqueta de reinicio para el panel/vista: "-" si no hay límite, si no la
    /// hora corta (o "ddd hh:mm" si es la ventana semanal).
    static func resetLabel(_ d: Date?, weekly: Bool) -> String {
        guard let d else { return "-" }
        return weekly ? fmtDddHM(d) : fmtHM(d)
    }
}
