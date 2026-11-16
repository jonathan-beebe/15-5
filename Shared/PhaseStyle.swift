import SwiftUI

extension Phase {
    var title: String {
        switch self {
        case .focus: "Focus"
        case .rest: "Break"
        }
    }

    /// Top to bottom. Focus matches the app icon gradient in scripts/make-icon.swift.
    var gradientColors: [Color] {
        switch self {
        case .focus: [
                Color(.sRGB, red: 0.40, green: 0.36, blue: 0.95),
                Color(.sRGB, red: 0.22, green: 0.17, blue: 0.70),
            ]
        case .rest: [
                Color(.sRGB, red: 0.12, green: 0.54, blue: 0.29),
                Color(.sRGB, red: 0.05, green: 0.36, blue: 0.19),
            ]
        }
    }

    /// The flowing gradient's brightest color. Fixed values, because the system colors change shade
    /// with the color scheme, which shows as a jump when iOS switches scheme during the fade.
    /// Each keeps white text at 3.5:1 or better, so the blended surface clears WCAG's 3:1.
    var flowAccent: Color {
        switch self {
        case .focus: Color(.sRGB, red: 0.749, green: 0.353, blue: 0.949)
        case .rest: Color(.sRGB, red: 0.13, green: 0.62, blue: 0.28)
        }
    }

    var tint: Color {
        switch self {
        case .focus: .purple
        case .rest: .green
        }
    }
}

/// 2 pulses per second stays under the WCAG 2.3.1 limit of 3 flashes per second.
enum FlashTiming {
    static let pulses = 3
    static let halfPeriod = 0.25
    static let reducedHalfPeriod = 0.75
    static let peakOpacity = 0.85
}
