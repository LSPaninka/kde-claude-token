import Foundation
import Security

// =====================================================================
//  Lectura del Keychain de macOS
//
//  Claude Code en macOS NO guarda `~/.claude/.credentials.json`: almacena las
//  credenciales en el Keychain como una "contraseña genérica" cuyo valor es el
//  mismo JSON `{ "claudeAiOauth": { "accessToken": ... } }`.
//
//  Servicio conocido: "Claude Code-credentials".
//
//  Nota: al ser una app distinta a Claude Code (y sin la misma firma), la
//  primera lectura mostrará el diálogo del sistema pidiendo permiso para
//  acceder a ese ítem del llavero; pulsa "Permitir siempre".
// =====================================================================

enum Keychain {

    /// Devuelve el dato (Data) de una contraseña genérica del llavero, o `nil`.
    static func readGenericPassword(service: String, account: String? = nil) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
