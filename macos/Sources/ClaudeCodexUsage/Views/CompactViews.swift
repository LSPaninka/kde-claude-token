import SwiftUI

// =====================================================================
//  Representación compacta (barra de menús) — modo minimalista (§6.5)
//
//  Claude: dos anillos escalables, cada uno con su etiqueta de reinicio al lado
//          (5h → HH:MM, semanal → ddd HH:MM).
//  Codex:  un anillo con su etiqueta semanal.
//
//  El grosor del anillo en la barra = max(2, tamañoAnillo*0.15), independiente
//  de `ringThickness` (que aplica a la vista completa).
// =====================================================================

/// Anillo pequeño + etiqueta de reinicio, tal como aparece en la barra de menús.
private struct CompactPair: View {
    var value: Double
    var label: String
    var ringColor: Color
    var trackColor: Color
    var textColor: Color
    var pctColor: Color
    var ringSize: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            RingChart(value: value,
                      ringColor: ringColor,
                      trackColor: trackColor,
                      textColor: pctColor,
                      subTextColor: textColor,
                      thickness: max(2, ringSize * 0.15))
                .frame(width: ringSize, height: ringSize)
            Text(label)
                .font(.system(size: max(8, ringSize * 0.30), weight: .bold))
                .foregroundColor(textColor)
        }
    }
}

/// Contenido de la barra de menús para Claude (dos pares).
struct ClaudeMenuBar: View {
    @ObservedObject var store: UsageStore<ClaudeUsage>
    @ObservedObject var settings: ClaudeSettings
    var thickness: CGFloat

    private var ringSize: CGFloat {
        let scale = max(0.5, min(1.0, Double(settings.panelIconScale) / 100.0))
        return CGFloat((max(8.0, Double(thickness) * scale)).rounded())
    }

    var body: some View {
        let u = store.value
        HStack(spacing: 10) {
            CompactPair(value: u?.fiveHour.utilization ?? 0,
                        label: Fmt.resetLabel(u?.fiveHour.resetsAt, weekly: false),
                        ringColor: Color(hex: settings.ring5hColor),
                        trackColor: Color(hex: settings.ringTrackColor),
                        textColor: settings.txtColor,
                        pctColor: settings.pctColor,
                        ringSize: ringSize)
            CompactPair(value: u?.sevenDay.utilization ?? 0,
                        label: Fmt.resetLabel(u?.sevenDay.resetsAt, weekly: true),
                        ringColor: Color(hex: settings.ring7dColor),
                        trackColor: Color(hex: settings.ringTrackColor),
                        textColor: settings.txtColor,
                        pctColor: settings.pctColor,
                        ringSize: ringSize)
        }
        .frame(height: thickness)
        .padding(.horizontal, 4)
        .fixedSize()
    }
}

/// Contenido de la barra de menús para Codex (un par).
struct CodexMenuBar: View {
    @ObservedObject var store: UsageStore<CodexUsage>
    @ObservedObject var settings: CodexSettings
    var thickness: CGFloat

    private var ringSize: CGFloat {
        let scale = max(0.5, min(1.0, Double(settings.panelIconScale) / 100.0))
        return CGFloat((max(8.0, Double(thickness) * scale)).rounded())
    }

    var body: some View {
        let u = store.value
        CompactPair(value: u?.primary.utilization ?? 0,
                    label: Fmt.resetLabel(u?.primary.resetsAt, weekly: true),
                    ringColor: Color(hex: settings.ringColor),
                    trackColor: Color(hex: settings.ringTrackColor),
                    textColor: settings.txtColor,
                    pctColor: settings.pctColor,
                    ringSize: ringSize)
            .frame(height: thickness)
            .padding(.horizontal, 4)
            .fixedSize()
    }
}
