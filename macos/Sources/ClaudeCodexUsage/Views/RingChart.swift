import SwiftUI

/// Anillo (donut) con el porcentaje en el centro (§6.2 de SPEC.md).
///
/// Dibujado con `Canvas`, sin librerías externas. El arco de progreso arranca
/// arriba (12 en punto), va en sentido horario y tiene extremo redondeado.
struct RingChart: View {
    var value: Double              // 0..100
    var ringColor: Color
    var trackColor: Color
    var textColor: Color
    var subTextColor: Color
    var thickness: CGFloat
    var caption: String = ""       // etiqueta pequeña bajo el porcentaje (ej: "5h")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let s = min(w, h)
            let v = max(0, min(100, value))

            ZStack {
                Canvas { ctx, size in
                    let cx = size.width / 2
                    let cy = size.height / 2
                    let r = min(size.width, size.height) / 2 - thickness / 2 - 1
                    guard r > 0 else { return }

                    // Pista de fondo (círculo completo).
                    let track = Path { p in
                        p.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                                 startAngle: .degrees(0), endAngle: .degrees(360),
                                 clockwise: false)
                    }
                    ctx.stroke(track, with: .color(trackColor),
                               style: StrokeStyle(lineWidth: thickness))

                    // Progreso.
                    if v > 0 {
                        let start = Angle.degrees(-90)
                        let end = Angle.degrees(-90 + 360 * (v / 100))
                        let arc = Path { p in
                            p.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                                     startAngle: start, endAngle: end, clockwise: false)
                        }
                        ctx.stroke(arc, with: .color(ringColor),
                                   style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                    }
                }

                // Texto central.
                VStack(spacing: 0) {
                    Text("\(Int(v.rounded()))%")
                        .font(.system(size: max(7, s * 0.28), weight: .bold))
                        .foregroundColor(textColor)
                    if !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: max(6, s * 0.14)))
                            .foregroundColor(subTextColor)
                            .opacity(0.8)
                    }
                }
            }
        }
    }
}
