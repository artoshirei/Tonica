import SwiftUI

struct BrandMark: View {
    enum Style {
        case menuBar
        case logo
    }

    let style: Style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !style.usesAnimation || reduceMotion)) { context in
            GeometryReader { _ in
                Canvas { graphicsContext, size in
                    let side = min(size.width, size.height)
                    let rect = CGRect(
                        x: (size.width - side) * 0.5,
                        y: (size.height - side) * 0.5,
                        width: side,
                        height: side
                    )
                    let phase = style.usesAnimation ? context.date.timeIntervalSinceReferenceDate : 0

                    switch style {
                    case .menuBar:
                        drawConcentricMark(in: rect, context: &graphicsContext, phase: phase, motion: .menuBar)
                    case .logo:
                        drawConcentricMark(in: rect, context: &graphicsContext, phase: phase, motion: .logo)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private enum MotionProfile {
        case menuBar
        case logo
    }

    private struct CircleSpec {
        let baseRatio: CGFloat
        let color: Color
        let scaleAmplitude: CGFloat
        let verticalTravel: CGFloat
        let phaseOffset: Double
    }

    private func drawConcentricMark(
        in rect: CGRect,
        context: inout GraphicsContext,
        phase: TimeInterval,
        motion: MotionProfile
    ) {
        let circleSpecs: [CircleSpec] = [
            CircleSpec(
                baseRatio: 1.0,
                color: Color(red: 1.0, green: 0.792, blue: 0.157),
                scaleAmplitude: 0,
                verticalTravel: 0,
                phaseOffset: 0
            ),
            CircleSpec(
                baseRatio: 496.0 / 652.0,
                color: Color(red: 0.0, green: 0.812, blue: 1.0),
                scaleAmplitude: motion == .menuBar ? 0.04 : 0.026,
                verticalTravel: motion == .menuBar ? rect.height * 0.012 : rect.height * 0.008,
                phaseOffset: -(.pi / 2.0)
            ),
            CircleSpec(
                baseRatio: 292.0 / 652.0,
                color: Color(red: 1.0, green: 0.235, blue: 0.675),
                scaleAmplitude: motion == .menuBar ? 0.08 : 0.045,
                verticalTravel: motion == .menuBar ? rect.height * 0.018 : rect.height * 0.012,
                phaseOffset: .pi / 5.0
            )
        ]

        if motion == .logo {
            let shadowRect = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06)
            context.fill(
                Path(ellipseIn: shadowRect),
                with: .radialGradient(
                    Gradient(colors: [.black.opacity(0.16), .clear]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 0,
                    endRadius: rect.width * 0.56
                )
            )
        }

        let cycle = phase * (.pi * 2.0) / 2.9
        let outerDiameter = rect.width * (motion == .menuBar ? 0.94 : 0.84)

        for spec in circleSpecs {
            let pulse = (sin(cycle + spec.phaseOffset) + 1.0) * 0.5
            let scale = 1.0 + (spec.scaleAmplitude * pulse)
            let offsetY = spec.verticalTravel * (pulse - 0.5)
            let size = outerDiameter * spec.baseRatio * scale
            let layerRect = CGRect(
                x: rect.midX - size * 0.5,
                y: rect.midY - size * 0.5 + offsetY,
                width: size,
                height: size
            )
            context.fill(Path(ellipseIn: layerRect), with: .color(spec.color))
        }
    }
}

private extension BrandMark.Style {
    var usesAnimation: Bool {
        switch self {
        case .menuBar, .logo:
            true
        }
    }
}
