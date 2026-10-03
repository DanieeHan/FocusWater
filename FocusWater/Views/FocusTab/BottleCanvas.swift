import SwiftUI

struct BottleCanvas: View {
    let progress: Double
    let serialNumber: Int
    let isCompleted: Bool
    var size: CGSize = CGSize(width: 200, height: 340)

    private var clampedProgress: Double {
        max(0, min(progress, 1))
    }

    private var displayProgress: Double {
        clampedProgress == 0 ? 0 : max(clampedProgress, 0.035)
    }

    var body: some View {
        ZStack {
            ambientGlow

            Canvas { context, canvasSize in
                let rect = CGRect(origin: .zero, size: canvasSize)
                let shell = bottlePath(in: rect)
                let glassInset = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.025)

                context.fill(
                    shell,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.bottleGlassEdge.opacity(0.78),
                            Color.bottleGlass,
                            Color.sectionBackground.opacity(0.34)
                        ]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    )
                )

                context.clip(to: shell)

                if displayProgress > 0 {
                    context.fill(
                        waterFillPath(in: rect),
                        with: .linearGradient(
                            Gradient(colors: [
                                Color.waterGradientStart.opacity(0.92),
                                Color.waterLight.opacity(0.96),
                                Color.waterGradientEnd.opacity(0.98)
                            ]),
                            startPoint: CGPoint(x: rect.midX, y: rect.minY),
                            endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                        )
                    )

                    let wave = waterSurfacePath(in: rect)
                    context.fill(wave, with: .color(.white.opacity(0.10)))
                    context.stroke(
                        wave,
                        with: .color(.white.opacity(0.68)),
                        style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
                    )
                }

                let verticalGlow = RoundedRectangle(
                    cornerRadius: rect.width * 0.06,
                    style: .continuous
                ).path(
                    in: CGRect(
                        x: rect.width * 0.28,
                        y: rect.height * 0.17,
                        width: rect.width * 0.10,
                        height: rect.height * 0.58
                    )
                )
                context.fill(
                    verticalGlow,
                    with: .linearGradient(
                        Gradient(colors: [.white.opacity(0.42), .white.opacity(0.10), .clear]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    )
                )

                let sideGlow = RoundedRectangle(
                    cornerRadius: rect.width * 0.03,
                    style: .continuous
                ).path(
                    in: CGRect(
                        x: rect.width * 0.62,
                        y: rect.height * 0.22,
                        width: rect.width * 0.06,
                        height: rect.height * 0.48
                    )
                )
                context.fill(sideGlow, with: .color(.white.opacity(0.10)))

                context.stroke(
                    shell,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.bottleGlassEdge,
                            Color.bottleStroke,
                            Color.bottleStroke.opacity(0.70)
                        ]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    ),
                    style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round)
                )

                context.stroke(
                    bottlePath(in: glassInset),
                    with: .color(Color.white.opacity(0.20)),
                    style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
                )
            }

            bottleLabel

            if isCompleted {
                capView
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func bottlePath(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        let neckWidth = w * 0.28
        let mouthWidth = w * 0.42
        let bodyWidth = w * 0.74
        let neckTop = h * 0.10
        let neckBottom = h * 0.225
        let bodyTop = h * 0.315
        let bodyBottom = h * 0.935
        let centerX = w * 0.5
        let mouthLeft = centerX - mouthWidth / 2
        let mouthRight = centerX + mouthWidth / 2
        let neckLeft = centerX - neckWidth / 2
        let neckRight = centerX + neckWidth / 2
        let bodyLeft = centerX - bodyWidth / 2
        let bodyRight = centerX + bodyWidth / 2

        return Path { path in
            path.move(to: CGPoint(x: x + mouthLeft, y: y + neckTop))
            path.addQuadCurve(
                to: CGPoint(x: x + mouthRight, y: y + neckTop),
                control: CGPoint(x: x + centerX, y: y + h * 0.055)
            )
            path.addLine(to: CGPoint(x: x + neckRight, y: y + neckBottom))
            path.addCurve(
                to: CGPoint(x: x + bodyRight, y: y + bodyTop),
                control1: CGPoint(x: x + neckRight, y: y + h * 0.275),
                control2: CGPoint(x: x + bodyRight, y: y + h * 0.255)
            )
            path.addLine(to: CGPoint(x: x + bodyRight, y: y + bodyBottom - w * 0.13))
            path.addQuadCurve(
                to: CGPoint(x: x + bodyRight - w * 0.13, y: y + bodyBottom),
                control: CGPoint(x: x + bodyRight, y: y + bodyBottom)
            )
            path.addLine(to: CGPoint(x: x + bodyLeft + w * 0.13, y: y + bodyBottom))
            path.addQuadCurve(
                to: CGPoint(x: x + bodyLeft, y: y + bodyBottom - w * 0.13),
                control: CGPoint(x: x + bodyLeft, y: y + bodyBottom)
            )
            path.addLine(to: CGPoint(x: x + bodyLeft, y: y + bodyTop))
            path.addCurve(
                to: CGPoint(x: x + neckLeft, y: y + neckBottom),
                control1: CGPoint(x: x + bodyLeft, y: y + h * 0.24),
                control2: CGPoint(x: x + neckLeft, y: y + h * 0.27)
            )
            path.addLine(to: CGPoint(x: x + mouthLeft, y: y + neckTop))
            path.closeSubpath()
        }
    }

    private func waterFillPath(in rect: CGRect) -> Path {
        let topLimit = rect.height * 0.25
        let bottom = rect.height * 0.94
        let currentY = bottom - (bottom - topLimit) * displayProgress
        var path = Path(CGRect(x: rect.minX, y: currentY, width: rect.width, height: rect.maxY - currentY))
        path.addPath(waterSurfacePath(in: rect))
        return path
    }

    private func waterSurfacePath(in rect: CGRect) -> Path {
        let topLimit = rect.height * 0.25
        let bottom = rect.height * 0.94
        let currentY = bottom - (bottom - topLimit) * displayProgress
        let left = rect.width * 0.18
        let right = rect.width * 0.82
        let amplitude: CGFloat = isCompleted ? 1.6 : 3.0

        return Path { path in
            path.move(to: CGPoint(x: left, y: currentY))
            path.addCurve(
                to: CGPoint(x: right, y: currentY),
                control1: CGPoint(x: rect.width * 0.34, y: currentY - amplitude),
                control2: CGPoint(x: rect.width * 0.66, y: currentY + amplitude)
            )
            path.addLine(to: CGPoint(x: right, y: rect.maxY))
            path.addLine(to: CGPoint(x: left, y: rect.maxY))
            path.closeSubpath()
        }
    }

    private var ambientGlow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [.waterGlow.opacity(0.10), .clear],
                    center: .center,
                    startRadius: 8,
                    endRadius: size.width * 0.64
                )
            )
            .frame(width: size.width * 0.92, height: size.height * 0.72)
            .blur(radius: 14)
            .offset(y: size.height * 0.10)
    }

    private var bottleLabel: some View {
        Capsule()
            .fill(Color.sectionBackground.opacity(0.64))
            .overlay(
                Capsule()
                    .stroke(Color.separatorLine, lineWidth: 0.8)
            )
            .frame(width: size.width * 0.28, height: size.height * 0.074)
            .overlay {
                Text("#\(serialNumber)")
                    .font(.system(size: size.width * 0.10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondaryText)
            }
            .shadow(color: Color.glassShadow.opacity(0.08), radius: 4, y: 2)
            .offset(y: size.height * 0.12)
    }

    private var capView: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let rect = CGRect(x: w * 0.34, y: h * 0.028, width: w * 0.32, height: h * 0.105)
            let cap = RoundedRectangle(cornerRadius: rect.width * 0.18, style: .continuous).path(in: rect)
            context.fill(
                cap,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.elevatedBackground,
                        Color.controlBackground
                    ]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
            context.stroke(cap, with: .color(Color.separatorLine), style: StrokeStyle(lineWidth: 1))
        }
    }
}
