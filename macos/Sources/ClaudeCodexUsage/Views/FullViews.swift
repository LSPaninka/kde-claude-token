import SwiftUI

// =====================================================================
//  Representación completa (popover) (§6.5)
// =====================================================================

/// Encabezado común: icono, título, indicador de carga, botones.
private struct FullHeader: View {
    var title: String
    var loading: Bool
    var textColor: Color
    var onRefresh: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cloud")
                .foregroundColor(textColor)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if loading {
                ProgressView().controlSize(.small)
            }
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Actualizar")
            Button(action: onSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Ajustes")
        }
    }
}

/// Pie común: error o última actualización.
private struct FullFooter: View {
    var errorMsg: String
    var lastUpdate: Date?
    var textColor: Color

    var body: some View {
        Group {
            if !errorMsg.isEmpty {
                Text("⚠ \(errorMsg)")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let lastUpdate {
                Text("Actualizado \(Fmt.fmtHM(lastUpdate))")
                    .font(.system(size: 11))
                    .foregroundColor(textColor)
                    .opacity(0.6)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// ---------------------------------------------------------------------
//  Claude
// ---------------------------------------------------------------------

struct ClaudeFullView: View {
    @ObservedObject var store: UsageStore<ClaudeUsage>
    @ObservedObject var settings: ClaudeSettings
    var onSettings: () -> Void

    private func resetInfo(_ limit: Limit?, weekly: Bool) -> String {
        guard let d = limit?.resetsAt else { return "sin datos" }
        var txt = "Reinicia " + (weekly ? Fmt.fmtDddHM(d) : Fmt.fmtHM(d))
        if settings.showRemaining {
            let ms = d.timeIntervalSince(store.now) * 1000
            txt += "  ·  faltan " + Fmt.fmtRemaining(ms)
        }
        return txt
    }

    var body: some View {
        let u = store.value
        VStack(alignment: .leading, spacing: 10) {
            FullHeader(title: "Uso de Claude",
                       loading: store.loading,
                       textColor: settings.txtColor,
                       onRefresh: { store.refresh() },
                       onSettings: onSettings)

            if settings.displayMode == "rings" {
                HStack(spacing: 18) {
                    ringColumn(value: u?.fiveHour.utilization ?? 0, caption: "5h",
                               color: Color(hex: settings.ring5hColor),
                               label: Fmt.resetLabel(u?.fiveHour.resetsAt, weekly: false))
                    ringColumn(value: u?.sevenDay.utilization ?? 0, caption: "7d",
                               color: Color(hex: settings.ring7dColor),
                               label: Fmt.resetLabel(u?.sevenDay.resetsAt, weekly: true))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    UsageBar(value: u?.fiveHour.utilization ?? 0,
                             fillColor: Color(hex: settings.bar5hColor),
                             trackColor: Color(hex: settings.barTrackColor),
                             textColor: settings.txtColor,
                             percentColor: settings.pctColor,
                             title: "Límite 5 horas",
                             rightText: resetInfo(u?.fiveHour, weekly: false))
                    UsageBar(value: u?.sevenDay.utilization ?? 0,
                             fillColor: Color(hex: settings.bar7dColor),
                             trackColor: Color(hex: settings.barTrackColor),
                             textColor: settings.txtColor,
                             percentColor: settings.pctColor,
                             title: "Límite semanal",
                             rightText: resetInfo(u?.sevenDay, weekly: true))
                }
            }

            Spacer(minLength: 0)
            FullFooter(errorMsg: store.errorMsg, lastUpdate: store.lastUpdate,
                       textColor: settings.txtColor)
        }
        .padding(12)
        .frame(width: 300, height: 190)
    }

    private func ringColumn(value: Double, caption: String, color: Color, label: String) -> some View {
        VStack(spacing: 6) {
            RingChart(value: value,
                      ringColor: color,
                      trackColor: Color(hex: settings.ringTrackColor),
                      textColor: settings.pctColor,
                      subTextColor: settings.txtColor,
                      thickness: CGFloat(settings.ringThickness),
                      caption: caption)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(settings.txtColor)
        }
    }
}

// ---------------------------------------------------------------------
//  Codex
// ---------------------------------------------------------------------

struct CodexFullView: View {
    @ObservedObject var store: UsageStore<CodexUsage>
    @ObservedObject var settings: CodexSettings
    var onSettings: () -> Void

    private var title: String {
        if let plan = store.value?.plan, !plan.isEmpty {
            return "Uso de Codex — \(plan)"
        }
        return "Uso de Codex"
    }

    private func resetInfo(_ limit: Limit?) -> String {
        guard let d = limit?.resetsAt else { return "sin datos" }
        var txt = "Reinicia " + Fmt.fmtDddHM(d)
        if settings.showRemaining {
            let ms = d.timeIntervalSince(store.now) * 1000
            txt += "  ·  faltan " + Fmt.fmtRemaining(ms)
        }
        return txt
    }

    var body: some View {
        let u = store.value
        VStack(alignment: .leading, spacing: 10) {
            FullHeader(title: title,
                       loading: store.loading,
                       textColor: settings.txtColor,
                       onRefresh: { store.refresh() },
                       onSettings: onSettings)

            if settings.displayMode == "rings" {
                VStack(spacing: 6) {
                    RingChart(value: u?.primary.utilization ?? 0,
                              ringColor: Color(hex: settings.ringColor),
                              trackColor: Color(hex: settings.ringTrackColor),
                              textColor: settings.pctColor,
                              subTextColor: settings.txtColor,
                              thickness: CGFloat(settings.ringThickness),
                              caption: "7d")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text(Fmt.resetLabel(u?.primary.resetsAt, weekly: true))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(settings.txtColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                UsageBar(value: u?.primary.utilization ?? 0,
                         fillColor: Color(hex: settings.barColor),
                         trackColor: Color(hex: settings.barTrackColor),
                         textColor: settings.txtColor,
                         percentColor: settings.pctColor,
                         title: "Límite semanal",
                         rightText: resetInfo(u?.primary))
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
            FullFooter(errorMsg: store.errorMsg, lastUpdate: store.lastUpdate,
                       textColor: settings.txtColor)
        }
        .padding(12)
        .frame(width: 300, height: 160)
    }
}
