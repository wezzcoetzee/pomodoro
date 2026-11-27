import SwiftUI

/// Canonical color source of truth, expressed in OKLCH and resolved to sRGB at runtime.
///
/// OKLCH keeps perceptual lightness and chroma stable across hues, so the phase
/// accents read as equally energetic and the tinted neutrals carry a consistent
/// trace of the active hue. The documented triples below are the reference values;
/// changing a color means changing its OKLCH here, never a hand-tuned hex.
///
/// Canonical palette (L 0-1, C, H in degrees):
///   Focus accent      0.68 / 0.19 / 35    warm driving ember
///   Focus accentSoft  0.74 / 0.13 / 35
///   Break accent      0.72 / 0.11 / 195   cool restful teal
///   Break accentSoft  0.78 / 0.08 / 195
///   Done              0.78 / 0.17 / 145   done green, block-completion moment only
///   Streak            0.80 / 0.16 / 85    charged amber, streak flame and count only
///   Reward            0.84 / 0.15 / 70    milestone amber, earned-accent only
///   Neutral canvas    0.17 / 0.012 / hue
///   Neutral surface   0.22 / 0.014 / hue
///   Neutral line      0.34 / 0.016 / hue
///   Neutral ink       0.95 / 0.006 / hue
///   Neutral inkDim    0.72 / 0.012 / hue
///
/// Verified WCAG AA (dark canvas, hue 35): ink 16.5:1, inkDim 7.7:1, focus digits
/// 6.1:1, break digits 8.1:1, done 10.2:1, streak 10.1:1; filled badges use `onAccent` (the
/// canvas ink), never `ink`, because light ink on an accent fill fails AA.
struct OKLCH {
    let l: Double
    let c: Double
    let h: Double

    var color: Color {
        let (r, g, b) = Self.linearComponents(l: l, c: c, h: h)
        return Color(.sRGB, red: gamma(r), green: gamma(g), blue: gamma(b), opacity: 1)
    }

    private func gamma(_ x: Double) -> Double {
        let clamped = min(max(x, 0), 1)
        return clamped >= 0.0031308 ? 1.055 * pow(clamped, 1 / 2.4) - 0.055 : 12.92 * clamped
    }

    private static func linearComponents(l: Double, c: Double, h: Double) -> (Double, Double, Double) {
        let hr = h * .pi / 180
        let a = c * cos(hr)
        let b = c * sin(hr)

        let lp = l + 0.3963377774 * a + 0.2158037573 * b
        let mp = l - 0.1055613458 * a - 0.0638541728 * b
        let sp = l - 0.0894841775 * a - 1.2914855480 * b

        let lc = lp * lp * lp
        let mc = mp * mp * mp
        let sc = sp * sp * sp

        let r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc
        return (r, g, bl)
    }
}

struct PhasePalette {
    let accent: Color
    let accentSoft: Color
    let canvas: Color
    let surface: Color
    let line: Color
    let ink: Color
    let inkDim: Color
    let onAccent: Color
}

enum PomodoroColors {
    /// The moment a focus block completes, on every surface. Nothing else is green.
    static let done = OKLCH(l: 0.78, c: 0.17, h: 145).color
    static let streak = OKLCH(l: 0.80, c: 0.16, h: 85).color
    static let streakSoft = OKLCH(l: 0.86, c: 0.11, h: 85).color
    static let reward = OKLCH(l: 0.84, c: 0.15, h: 70).color

    private static let focusPalette = palette(
        accent: OKLCH(l: 0.68, c: 0.19, h: 35),
        accentSoft: OKLCH(l: 0.74, c: 0.13, h: 35),
        hue: 35
    )

    private static let breakPalette = palette(
        accent: OKLCH(l: 0.72, c: 0.11, h: 195),
        accentSoft: OKLCH(l: 0.78, c: 0.08, h: 195),
        hue: 195
    )

    static func palette(for phase: TimerPhase) -> PhasePalette {
        switch phase {
        case .idle, .focus: return focusPalette
        case .shortBreak, .longBreak: return breakPalette
        }
    }

    private static func palette(accent: OKLCH, accentSoft: OKLCH, hue: Double) -> PhasePalette {
        let canvas = OKLCH(l: 0.17, c: 0.012, h: hue).color
        return PhasePalette(
            accent: accent.color,
            accentSoft: accentSoft.color,
            canvas: canvas,
            surface: OKLCH(l: 0.22, c: 0.014, h: hue).color,
            line: OKLCH(l: 0.34, c: 0.016, h: hue).color,
            ink: OKLCH(l: 0.95, c: 0.006, h: hue).color,
            inkDim: OKLCH(l: 0.72, c: 0.012, h: hue).color,
            onAccent: canvas
        )
    }
}

/// Surface dimensions shared by the window shell and the SwiftUI content, so the
/// container and its panes cannot drift out of alignment.
enum SurfaceMetrics {
    static let mainWidth: CGFloat = 380
    static let mainHeight: CGFloat = 480
    static let miniWidth: CGFloat = 220
    static let miniHeight: CGFloat = 116
}

enum PomodoroMotion {
    /// Ease-out-quint. Fast start, long settle, no overshoot.
    static let ringFill = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.35)
    static let celebrate = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.45)
    /// The orb's pill sliding out, and the orb growing from quiet. Same curve, one-shot.
    static let orbSlide = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.4)
}

enum PomodoroFont {
    /// The hero countdown. Fixed by the Hero-Digit rule so it never reflows or jitters.
    static func timer(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
    }

    /// The streak count. Fixed alongside the timer as the second hero numeral.
    static let streakNumber = Font.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit()
}

/// Non-hero text tiers. Sizes scale with the user's accessibility text size via
/// `@ScaledMetric`, while the timer and streak numerals stay fixed as the heroes.
enum PomodoroTextRole {
    case headline, title, body, label

    var baseSize: CGFloat {
        switch self {
        case .headline: return 20
        case .title: return 15
        case .body: return 13
        case .label: return 11
        }
    }

    var weight: Font.Weight {
        switch self {
        case .headline: return .bold
        case .title: return .semibold
        case .body: return .regular
        case .label: return .medium
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .headline: return .title3
        case .title: return .headline
        case .body: return .body
        case .label: return .caption
        }
    }
}

private struct ScaledPomodoroText: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let uppercased: Bool
    private let kerning: CGFloat

    init(role: PomodoroTextRole, uppercased: Bool = false, kerning: CGFloat = 0) {
        _size = ScaledMetric(wrappedValue: role.baseSize, relativeTo: role.textStyle)
        weight = role.weight
        self.uppercased = uppercased
        self.kerning = kerning
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight, design: .rounded))
            .textCase(uppercased ? .uppercase : nil)
            .kerning(kerning)
    }
}

extension View {
    func pomodoroText(_ role: PomodoroTextRole) -> some View {
        modifier(ScaledPomodoroText(role: role))
    }

    func pomodoroLabelStyle() -> some View {
        modifier(ScaledPomodoroText(role: .label, uppercased: true, kerning: 0.8))
    }
}
