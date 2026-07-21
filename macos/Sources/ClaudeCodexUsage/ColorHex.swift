import SwiftUI
import AppKit

// =====================================================================
//  Conversión de color <-> cadena hexadecimal #AARRGGBB (§4.3 de SPEC.md)
// =====================================================================

extension Color {

    /// Crea un color a partir de `#AARRGGBB` (alfa primero, 8 dígitos hex).
    /// También acepta `#RRGGBB` (alfa = FF). Cadenas inválidas → gris opaco.
    init(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("#") { str.removeFirst() }

        var a = 1.0, r = 0.5, g = 0.5, b = 0.5
        if str.count == 8, let v = UInt64(str, radix: 16) {
            a = Double((v >> 24) & 0xff) / 255.0
            r = Double((v >> 16) & 0xff) / 255.0
            g = Double((v >> 8) & 0xff) / 255.0
            b = Double(v & 0xff) / 255.0
        } else if str.count == 6, let v = UInt64(str, radix: 16) {
            r = Double((v >> 16) & 0xff) / 255.0
            g = Double((v >> 8) & 0xff) / 255.0
            b = Double(v & 0xff) / 255.0
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Serializa el color como cadena `#AARRGGBB`.
    var hexAARRGGBB: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        func h(_ x: CGFloat) -> String {
            let v = Int((max(0, min(1, x)) * 255).rounded())
            return String(format: "%02x", v)
        }
        return "#" + h(ns.alphaComponent) + h(ns.redComponent) + h(ns.greenComponent) + h(ns.blueComponent)
    }
}
