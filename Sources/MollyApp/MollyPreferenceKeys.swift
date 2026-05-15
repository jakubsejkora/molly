import Foundation
import SwiftUI

enum MollyPreferenceKeys {
    static let awakeLane = "molly.preference.awake"
    static let connectivityLane = "molly.preference.connectivity"
    static let mirrorTimer = "molly.preference.mirrortimers"
    static let notifications = "molly.preference.notifications"
    static let launchAtLogin = "molly.preference.loginitem"
    /// `MollyAppearance` raw value (`system`, `light`, `dark`).
    static let appearance = "molly.preference.appearance"
}

enum MollyAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` means follow macOS system appearance.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum MollyTimerPreset: String, CaseIterable, Identifiable {
    case manual
    case thirtyMinutes = "30m"
    case twoHours = "2h"
    case fourHours = "4h"

    var id: String { rawValue }

    /// Human label for menus.
    var menuTitle: String {
        switch self {
        case .manual: return "Manual (until you turn off)"
        case .thirtyMinutes: return "30 minutes"
        case .twoHours: return "2 hours"
        case .fourHours: return "4 hours"
        }
    }

    var durationSeconds: TimeInterval? {
        switch self {
        case .manual: return nil
        case .thirtyMinutes: return 30 * 60
        case .twoHours: return 2 * 3600
        case .fourHours: return 4 * 3600
        }
    }
}

extension Notification.Name {
    static let mollyRevealDashboard = Notification.Name("mollyRevealDashboardNotification")
}
