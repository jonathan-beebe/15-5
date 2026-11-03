import SwiftUI

extension Phase {
    var title: String {
        switch self {
        case .focus: "Focus"
        case .rest: "Break"
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
