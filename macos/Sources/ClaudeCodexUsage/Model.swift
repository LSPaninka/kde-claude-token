import Foundation

// =====================================================================
//  Modelo de datos normalizado (§3 de SPEC.md)
// =====================================================================

/// Un límite de uso: porcentaje utilizado y momento absoluto de reinicio.
struct Limit: Equatable {
    /// 0..100 (porcentaje usado). Ausente/null → 0.
    var utilization: Double
    /// Momento absoluto del reinicio, o `nil` si no está establecido (se muestra "-").
    var resetsAt: Date?
}

/// Uso de Claude Pro Individual: límite de 5 h y límite semanal.
struct ClaudeUsage: Equatable {
    var fiveHour: Limit
    var sevenDay: Limit
}

/// Uso semanal de Codex (ChatGPT): un solo límite y el plan informado.
struct CodexUsage: Equatable {
    var primary: Limit
    var plan: String?
}

// =====================================================================
//  Errores de obtención (§9 de SPEC.md)
// =====================================================================

enum UsageError: LocalizedError {
    case noToken(String)          // no se pudo leer el token del archivo
    case emptyResponse            // cuerpo vacío
    case badJSON                  // JSON no parseable
    case api(String)             // objeto de error de la API
    case unexpected               // forma inesperada
    case unauthorized             // HTTP 401 / token caducado

    var errorDescription: String? {
        switch self {
        case .noToken(let detail):
            return "No se encontró el token de sesión. \(detail)"
        case .emptyResponse:
            return "Sin respuesta. Revisa la red o la sesión."
        case .badJSON:
            return "No se pudo interpretar la respuesta."
        case .api(let msg):
            return msg
        case .unexpected:
            return "Respuesta inesperada de la API."
        case .unauthorized:
            return "Sesión caducada (401). Vuelve a iniciar sesión en la CLI."
        }
    }
}

// =====================================================================
//  Parseo de fechas
// =====================================================================

enum DateParse {

    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parsea una cadena ISO 8601 con zona horaria.
    ///
    /// Tolerante a fracciones de segundo de longitud arbitraria (p. ej. Claude
    /// devuelve microsegundos: `...59.314716+00:00`), que `ISO8601DateFormatter`
    /// no acepta directamente; en ese caso recortamos a 3 dígitos.
    static func iso8601(_ s: String) -> Date? {
        if let d = isoWithFraction.date(from: s) { return d }
        if let d = isoPlain.date(from: s) { return d }

        // Recortar la fracción de segundo a milisegundos (3 dígitos) y reintentar.
        if let r = s.range(of: #"\.\d+"#, options: .regularExpression) {
            let digits = s[r].dropFirst()                      // sin el punto
            let ms = String((digits + "000").prefix(3))
            let trimmed = s.replacingCharacters(in: r, with: "." + ms)
            if let d = isoWithFraction.date(from: trimmed) { return d }
        }
        return nil
    }
}
