import SwiftUI

/// Barra horizontal de progreso con título, porcentaje y una línea inferior de
/// información (hora de reinicio / tiempo restante) (§6.3 de SPEC.md).
struct UsageBar: View {
    var value: Double              // 0..100
    var fillColor: Color
    var trackColor: Color
    var textColor: Color
    var percentColor: Color
    var title: String
    var rightText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(textColor)
                Spacer()
                Text("\(Int(value.rounded()))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(percentColor)
            }

            GeometryReader { geo in
                let full = geo.size.width
                let frac = max(0, min(1, value / 100))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(trackColor)
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 7)
                        .fill(fillColor)
                        .frame(width: full * frac, height: 14)
                        .animation(.easeOut(duration: 0.4), value: value)
                }
            }
            .frame(height: 14)

            Text(rightText)
                .font(.system(size: 10))
                .foregroundColor(textColor)
                .opacity(0.8)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
