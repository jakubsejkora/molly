import SwiftUI

/// Wispr-inspired tokens: soft canvas, white cards; light mode uses muted teal + sage; dark mode uses warm sand accents (not mint).
enum MollyTheme {

    enum ColorToken {
        case sidebarChrome
        case sidebarSelection
        case detailCanvas
        case card
        case border
        case accent
        case accentSoft
        /// Sidebar list titles: explicit contrast on chrome + material (avoids faint system sidebar styling).
        case sidebarRowLabel
        case calloutFill

        func resolve(for scheme: ColorScheme) -> SwiftUI.Color {
            switch self {
            case .sidebarChrome:
                if scheme == .dark {
                    return SwiftUI.Color(red: 0.13, green: 0.13, blue: 0.14)
                }
                return SwiftUI.Color(red: 0.93, green: 0.92, blue: 0.90)
            case .sidebarSelection:
                if scheme == .dark {
                    return SwiftUI.Color.white.opacity(0.10)
                }
                return SwiftUI.Color(red: 0.98, green: 0.96, blue: 0.92)
            case .detailCanvas:
                if scheme == .dark {
                    return SwiftUI.Color(red: 0.10, green: 0.10, blue: 0.11)
                }
                return SwiftUI.Color(red: 0.965, green: 0.958, blue: 0.945)
            case .card:
                if scheme == .dark {
                    return SwiftUI.Color(red: 0.17, green: 0.17, blue: 0.18)
                }
                return SwiftUI.Color.white
            case .border:
                if scheme == .dark {
                    return SwiftUI.Color.white.opacity(0.09)
                }
                return SwiftUI.Color.black.opacity(0.055)
            case .accent:
                if scheme == .dark {
                    return SwiftUI.Color(red: 0.90, green: 0.72, blue: 0.52)
                }
                return SwiftUI.Color(red: 0.18, green: 0.44, blue: 0.42)
            case .accentSoft:
                if scheme == .dark {
                    return SwiftUI.Color(red: 0.32, green: 0.24, blue: 0.18)
                }
                return SwiftUI.Color(red: 0.82, green: 0.92, blue: 0.88)
            case .sidebarRowLabel:
                if scheme == .dark {
                    return SwiftUI.Color(red: 0.94, green: 0.94, blue: 0.95)
                }
                return SwiftUI.Color(red: 0.14, green: 0.14, blue: 0.15)
            case .calloutFill:
                return ColorToken.accent.resolve(for: scheme).opacity(scheme == .dark ? 0.12 : 0.08)
            }
        }
    }

    /// Flat studio canvas (Wispr uses almost no heavy gradient).
    struct DetailCanvasBackground: View {
        @Environment(\.colorScheme) private var scheme

        var body: some View {
            ColorToken.detailCanvas.resolve(for: scheme)
                .ignoresSafeArea()
        }
    }

    /// Hairline between the fixed sidebar rail and the detail canvas.
    struct SidebarDivider: View {
        @Environment(\.colorScheme) private var scheme

        var body: some View {
            Rectangle()
                .fill(ColorToken.border.resolve(for: scheme))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
    }
}

struct MollyCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MollyTheme.ColorToken.card.resolve(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(MollyTheme.ColorToken.border.resolve(for: scheme), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(scheme == .dark ? 0.35 : 0.05),
                radius: scheme == .dark ? 20 : 14,
                x: 0,
                y: scheme == .dark ? 10 : 5
            )
    }
}

extension View {
    func mollyCard() -> some View { modifier(MollyCardModifier()) }
}

extension Font {
    static func mollyPageTitle() -> Font {
        .system(size: 28, weight: .semibold, design: .rounded)
    }

    static func mollySectionTitle() -> Font {
        .system(.title3, design: .rounded).weight(.semibold)
    }

    static func mollyCardEyebrow() -> Font {
        .system(.caption, design: .rounded).weight(.semibold)
    }

    static func mollyHeroMetric() -> Font {
        .system(size: 36, weight: .semibold, design: .rounded)
    }

    static func mollyFriendlyLargeTitle() -> Font {
        .system(.largeTitle, design: .rounded).weight(.semibold)
    }

    static func mollyFriendlyTitle() -> Font {
        .system(.title2, design: .rounded).weight(.semibold)
    }

    static func mollyFriendlyHeadline() -> Font {
        .system(.headline, design: .rounded).weight(.semibold)
    }
}
