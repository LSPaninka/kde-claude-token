import Foundation

// =====================================================================
//  Obtención de datos nativa (§2 de SPEC.md)
//
//  A diferencia de la referencia QML, NO ejecutamos `curl`/`jq`: leemos las
//  credenciales en local (Keychain de macOS para Claude Code, o archivo) y
//  hacemos la petición con URLSession fijando las cabeceras exactas. El token
//  solo se envía al host correspondiente.
// =====================================================================

enum Credentials {

    /// Expande `~` y variables de entorno de una ruta y devuelve una URL de archivo.
    static func expand(_ rawPath: String) -> URL {
        var path = rawPath
        // Expandir variables de entorno tipo $HOME / ${CODEX_HOME:-...}
        // (soporte simple: $VAR y ${VAR:-default}).
        path = expandEnv(path)
        path = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }

    private static func expandEnv(_ input: String) -> String {
        var result = input
        // ${VAR:-default}
        while let range = result.range(of: #"\$\{([A-Za-z_][A-Za-z0-9_]*):-([^}]*)\}"#,
                                       options: .regularExpression) {
            let match = String(result[range])
            let inner = match.dropFirst(2).dropLast()               // VAR:-default
            let parts = inner.components(separatedBy: ":-")
            let name = parts.first ?? ""
            let def = parts.count > 1 ? parts[1] : ""
            let value = ProcessInfo.processInfo.environment[name] ?? def
            result.replaceSubrange(range, with: value)
        }
        // ${VAR} y $VAR
        while let range = result.range(of: #"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?"#,
                                       options: .regularExpression) {
            let match = String(result[range])
            let name = match.replacingOccurrences(of: "[${}]", with: "", options: .regularExpression)
            let value = ProcessInfo.processInfo.environment[name] ?? ""
            result.replaceSubrange(range, with: value)
        }
        return result
    }

    /// Navega por las claves anidadas de un JSON (Data) y devuelve una cadena
    /// no vacía (p. ej. ["claudeAiOauth", "accessToken"]).
    static func readString(data: Data, keys: [String]) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var node: Any? = obj
        for (i, key) in keys.enumerated() {
            guard let dict = node as? [String: Any] else { return nil }
            node = dict[key]
            if i == keys.count - 1 {
                if let s = node as? String { return s.isEmpty ? nil : s }
                return nil
            }
        }
        return nil
    }

    /// Igual que el anterior pero leyendo desde un archivo.
    static func readString(path: URL, keys: [String]) -> String? {
        guard let data = try? Data(contentsOf: path) else { return nil }
        return readString(data: data, keys: keys)
    }
}

// ---------------------------------------------------------------------
//  Cliente de Claude (§2.1)
// ---------------------------------------------------------------------

enum ClaudeClient {

    /// Servicios del Keychain donde Claude Code (macOS) guarda las credenciales.
    private static let keychainServices = ["Claude Code-credentials", "Claude Code"]

    private static let tokenKeys = ["claudeAiOauth", "accessToken"]

    /// Resuelve el accessToken de Claude según el origen disponible:
    ///  1. Si el usuario fijó una ruta en la configuración → ese archivo.
    ///  2. Keychain de macOS (Claude Code).
    ///  3. Archivo `~/.claude/.credentials.json` (Linux / versiones antiguas).
    static func accessToken(configured: String) -> String? {
        let trimmed = configured.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return Credentials.readString(path: Credentials.expand(trimmed), keys: tokenKeys)
        }
        // Keychain de macOS.
        for service in keychainServices {
            if let data = Keychain.readGenericPassword(service: service),
               let token = Credentials.readString(data: data, keys: tokenKeys) {
                return token
            }
        }
        // Respaldo: archivo por defecto.
        return Credentials.readString(path: Credentials.expand("~/.claude/.credentials.json"),
                                      keys: tokenKeys)
    }

    static func fetch(credentialsPath: String) async throws -> ClaudeUsage {
        guard let token = accessToken(configured: credentialsPath) else {
            throw UsageError.noToken("Inicia sesión con Claude Code (Keychain de macOS o ~/.claude/.credentials.json).")
        }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("claude-code/2.1.211", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw UsageError.unauthorized
        }
        if data.isEmpty { throw UsageError.emptyResponse }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.badJSON
        }
        if let err = obj["error"] as? [String: Any] {
            throw UsageError.api((err["message"] as? String) ?? "Error de la API")
        }
        guard obj["five_hour"] != nil || obj["seven_day"] != nil else {
            throw UsageError.unexpected
        }

        return ClaudeUsage(
            fiveHour: parseLimit(obj["five_hour"]),
            sevenDay: parseLimit(obj["seven_day"])
        )
    }

    /// Normaliza una sección `{ utilization, resets_at (ISO 8601) }`.
    private static func parseLimit(_ raw: Any?) -> Limit {
        guard let dict = raw as? [String: Any] else { return Limit(utilization: 0, resetsAt: nil) }
        let util = (dict["utilization"] as? NSNumber)?.doubleValue ?? 0
        var reset: Date? = nil
        if let s = dict["resets_at"] as? String { reset = DateParse.iso8601(s) }
        return Limit(utilization: util, resetsAt: reset)
    }
}

// ---------------------------------------------------------------------
//  Cliente de Codex / ChatGPT (§2.2)
// ---------------------------------------------------------------------

enum CodexClient {

    static func resolvedPath(_ configured: String) -> URL {
        let trimmed = configured.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return Credentials.expand("${CODEX_HOME:-~/.codex}/auth.json")
        }
        return Credentials.expand(trimmed)
    }

    static func fetch(credentialsPath: String) async throws -> CodexUsage {
        let path = resolvedPath(credentialsPath)
        guard let token = Credentials.readString(path: path, keys: ["tokens", "access_token"]) else {
            throw UsageError.noToken("Inicia sesión con la CLI de Codex.")
        }
        // account_id: primero tokens.account_id, con respaldo a la raíz (versiones antiguas).
        let account = Credentials.readString(path: path, keys: ["tokens", "account_id"])
            ?? Credentials.readString(path: path, keys: ["account_id"])
            ?? ""

        var req = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(account, forHTTPHeaderField: "ChatGPT-Account-ID")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw UsageError.unauthorized
        }
        if data.isEmpty { throw UsageError.emptyResponse }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.badJSON
        }
        if let err = obj["error"] as? [String: Any] {
            throw UsageError.api((err["message"] as? String) ?? "Error de la API")
        }
        guard let rateLimit = obj["rate_limit"] as? [String: Any],
              let primary = rateLimit["primary_window"] as? [String: Any] else {
            if let detail = obj["detail"] as? String { throw UsageError.api(detail) }
            throw UsageError.unexpected
        }

        let util = (primary["used_percent"] as? NSNumber)?.doubleValue ?? 0
        var reset: Date? = nil
        if let secs = (primary["reset_at"] as? NSNumber)?.doubleValue {
            reset = Date(timeIntervalSince1970: secs)      // reset_at está en segundos Unix
        }
        let plan = obj["plan_type"] as? String

        return CodexUsage(primary: Limit(utilization: util, resetsAt: reset), plan: plan)
    }
}
