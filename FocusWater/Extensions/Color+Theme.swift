import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension Color {
    static var waterLight: Color { Color(light: .rgb(0.56, 0.78, 0.96), dark: .rgb(0.32, 0.67, 1.00)) }
    static var waterDark: Color { Color(light: .rgb(0.00, 0.48, 1.00), dark: .rgb(0.04, 0.52, 1.00)) }
    static var waterGlow: Color { Color(light: .rgb(0.82, 0.91, 1.00), dark: .rgb(0.22, 0.42, 0.64)) }
    static var waterGradientStart: Color { Color(light: .rgb(0.94, 0.98, 1.00), dark: .rgb(0.56, 0.76, 0.96)) }
    static var waterGradientEnd: Color { Color(light: .rgb(0.00, 0.48, 1.00), dark: .rgb(0.04, 0.40, 0.86)) }
    static var bottleStroke: Color { Color(light: .rgb(0.78, 0.78, 0.80), dark: .rgb(0.42, 0.42, 0.44)) }
    static var bottleGlass: Color { Color(light: .white(1.0, alpha: 0.72), dark: .white(1.0, alpha: 0.08)) }
    static var bottleGlassEdge: Color { Color(light: .white(1.0, alpha: 0.96), dark: .white(1.0, alpha: 0.34)) }
    static var accentBlue: Color { Color(light: .rgb(0.00, 0.48, 1.00), dark: .rgb(0.04, 0.52, 1.00)) }
    static var accentBlueDeep: Color { Color(light: .rgb(0.00, 0.37, 0.82), dark: .rgb(0.00, 0.42, 0.92)) }
    static var appBackgroundTop: Color { Color(light: .rgb(0.95, 0.95, 0.97), dark: .rgb(0.00, 0.00, 0.00)) }
    static var appBackgroundMid: Color { Color(light: .rgb(0.95, 0.95, 0.97), dark: .rgb(0.04, 0.04, 0.05)) }
    static var appBackgroundBottom: Color { Color(light: .rgb(0.91, 0.95, 0.98), dark: .rgb(0.035, 0.055, 0.075)) }
    static var groupedBackground: Color { Color(light: .rgb(0.95, 0.95, 0.97), dark: .rgb(0.00, 0.00, 0.00)) }
    static var sectionBackground: Color { Color(light: .white(1.0), dark: .rgb(0.11, 0.11, 0.12)) }
    static var elevatedBackground: Color { Color(light: .rgb(0.98, 0.98, 0.99), dark: .rgb(0.17, 0.17, 0.18)) }
    static var controlBackground: Color { Color(light: .rgb(0.90, 0.90, 0.92), dark: .rgb(0.23, 0.23, 0.24)) }
    static var separatorLine: Color { Color(light: .white(0.0, alpha: 0.12), dark: .white(1.0, alpha: 0.13)) }
    static var cardStroke: Color { Color(light: .white(0.0, alpha: 0.07), dark: .white(1.0, alpha: 0.10)) }
    static var glassShadow: Color { Color(light: .white(0.0, alpha: 0.055), dark: .white(0.0, alpha: 0.22)) }
    static var primaryText: Color { Color(light: .white(0.0, alpha: 0.88), dark: .white(1.0, alpha: 0.96)) }
    static var secondaryText: Color { Color(light: .white(0.0, alpha: 0.62), dark: .white(1.0, alpha: 0.72)) }
    static var tertiaryText: Color { Color(light: .white(0.0, alpha: 0.44), dark: .white(1.0, alpha: 0.46)) }
    static var neutralIcon: Color { Color(light: .white(0.0, alpha: 0.46), dark: .white(1.0, alpha: 0.58)) }
    static var successTint: Color { Color(light: .rgb(0.20, 0.78, 0.35), dark: .rgb(0.19, 0.82, 0.35)) }
    static var warningTint: Color { Color(light: .rgb(0.95, 0.58, 0.12), dark: .rgb(1.00, 0.62, 0.18)) }

    static var waterGradient: LinearGradient {
        LinearGradient(
            colors: [.waterGradientStart, .waterLight, .waterGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var bottleHighlight: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.64), Color.white.opacity(0.12), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var appBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [.appBackgroundTop, .appBackgroundMid, .appBackgroundBottom],
            startPoint: .top,
            endPoint: .bottomTrailing
        )
    }

    static var glassCardFill: LinearGradient {
        LinearGradient(
            colors: [
                .sectionBackground,
                .elevatedBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryButtonFill: LinearGradient {
        LinearGradient(
            colors: [.accentBlue, .accentBlueDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var secondaryButtonFill: LinearGradient {
        LinearGradient(
            colors: [.controlBackground, .elevatedBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var segmentedControlFill: Color {
        Color(light: .white(0.0, alpha: 0.07), dark: .white(1.0, alpha: 0.10))
    }

    static var segmentedSelectedFill: Color {
        Color(light: .white(1.0, alpha: 0.96), dark: .white(1.0, alpha: 0.17))
    }
}

private extension Color {
    init(light: PlatformColor, dark: PlatformColor) {
#if os(macOS)
        self = Color(
            nsColor: PlatformColor(name: nil) { appearance in
                let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
                return bestMatch == .darkAqua ? dark : light
            }
        )
#elseif canImport(UIKit)
        self = Color(
            uiColor: PlatformColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
#endif
    }
}

#if os(macOS)
private typealias PlatformColor = NSColor
#elseif canImport(UIKit)
private typealias PlatformColor = UIColor
#endif

private extension PlatformColor {
    static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1.0) -> PlatformColor {
        PlatformColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    static func white(_ value: CGFloat, alpha: CGFloat = 1.0) -> PlatformColor {
        PlatformColor(white: value, alpha: alpha)
    }
}

extension View {
    func glassCardBackground(cornerRadius: CGFloat, shadowRadius: CGFloat = 8, shadowY: CGFloat = 3) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.glassCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
                .shadow(color: Color.glassShadow, radius: shadowRadius, y: shadowY)
        )
    }

    @ViewBuilder
    func platformHelp(_ text: String) -> some View {
        #if os(macOS)
        self.help(text)
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformMinFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        #if os(macOS)
        self.frame(minWidth: width, minHeight: height)
        #else
        self
        #endif
    }
}
