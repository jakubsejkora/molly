import SwiftUI

struct MainDashboard: View {

    @ObservedObject var surface: MollySessionController

    @SceneStorage("molly.mainSidebar.v1") private var selectionRaw: String = MainSidebarSelection.overview.rawValue

    @AppStorage(MollyPreferenceKeys.appearance) private var appearanceStore: String = MollyAppearance.system.rawValue

    @Environment(\.colorScheme) private var scheme

    @AppStorage("molly.mainSidebar.migrated") private var sidebarMigrated: Bool = false

    private var preferredAppearance: ColorScheme? {

        MollyAppearance(rawValue: appearanceStore)?.preferredColorScheme

    }

    private var sidebarSelection: MainSidebarSelection {

        MainSidebarSelection(rawValue: selectionRaw) ?? .overview

    }

    private var sidebarSelectionBinding: Binding<MainSidebarSelection> {

        Binding(
            get: { MainSidebarSelection(rawValue: selectionRaw) ?? .overview },
            set: { selectionRaw = $0.rawValue }
        )
    }

    var body: some View {

        NavigationSplitView {

            List(selection: sidebarSelectionBinding) {

                ForEach(MainSidebarSelection.allCases) { pane in

                    Label(pane.title, systemImage: pane.glyph)

                        .tag(pane)

                }

            }

            .listStyle(.sidebar)

            .navigationSplitViewColumnWidth(min: 168, ideal: 190, max: 240)

            .navigationTitle("Molly")

        } detail: {

            ZStack(alignment: .topLeading) {

                MollyTheme.DetailCanvasBackground()

                Group {

                    switch sidebarSelection {

                    case .overview:

                        OverviewPane(surface: surface)

                    case .log:

                        LogsPane(journal: surface.logs)

                    case .settings:

                        PreferencesPane(surface: surface)

                    }

                }

                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)

                .padding(18)

            }

            .frame(maxWidth: .infinity, maxHeight: .infinity)

        }

        .tint(MollyTheme.ColorToken.accent.resolve(for: scheme))

        .preferredColorScheme(preferredAppearance)

        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .onAppear {

            migrateLegacySidebarSelectionIfNeeded()

        }

    }

    private func migrateLegacySidebarSelectionIfNeeded() {

        guard sidebarMigrated == false else { return }

        if let legacy = UserDefaults.standard.string(forKey: "molly.sidebar") {

            switch legacy {

            case "session", "connectivity", "insights":

                selectionRaw = MainSidebarSelection.overview.rawValue

            case "logs":

                selectionRaw = MainSidebarSelection.log.rawValue

            case "settings", "about":

                selectionRaw = MainSidebarSelection.settings.rawValue

            default:

                break

            }

        }

        sidebarMigrated = true

    }

}

private enum MainSidebarSelection: String, CaseIterable, Identifiable, Hashable {

    case overview

    case log

    case settings

    var id: String { rawValue }

    var title: String {

        switch self {

        case .overview: return "Overview"

        case .log: return "Log"

        case .settings: return "Settings"

        }

    }

    var glyph: String {

        switch self {

        case .overview: return "rectangle.split.2x1"

        case .log: return "doc.text"

        case .settings: return "gearshape"

        }

    }

}

private enum DashboardPaneStyle {

    case standalone

    case embedded

}

// MARK: - Overview (Session + Connectivity + Insights)

private struct OverviewPane: View {

    @ObservedObject var surface: MollySessionController

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                PageHeader(

                    title: "Overview",

                    subtitle: "Lanes, keepalive telemetry, and status — one place."

                )

                overviewSectionTitle("Lanes")

                SessionPane(surface: surface, style: .embedded)

                overviewSectionTitle("Connectivity")

                ConnectivityPane(probes: surface.probes, pilot: surface, style: .embedded)

                overviewSectionTitle("Status")

                InsightPane(surface: surface, style: .embedded)

            }

            .frame(maxWidth: .infinity, alignment: .leading)

        }

    }

    private func overviewSectionTitle(_ text: String) -> some View {

        Text(text.uppercased())

            .font(.mollyCardEyebrow())

            .foregroundStyle(.tertiary)

            .tracking(0.6)

            .padding(.top, 4)

    }

}

// MARK: - Session

private struct SessionPane: View {

    @ObservedObject var surface: MollySessionController

    @Environment(\.colorScheme) private var scheme

    var style: DashboardPaneStyle = .standalone

    var body: some View {

        let stack = VStack(alignment: .leading, spacing: style == .embedded ? 18 : 28) {

            if style == .standalone {

                PageHeader(

                    title: "Session",

                    subtitle: "See what’s running and tune timers — Molly still lives quietly in the menu bar."

                )

            }

            LazyVGrid(

                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],

                spacing: 16

            ) {

                HeroLaneCard(

                    eyebrow: "Awake",

                    title: "Idle sleep",

                    caption: "Keeps the system reachable for agents; your display can still sleep.",

                    icon: "moon.stars.fill",

                    isOn: surface.awakeEnabled,

                    onToggle: { surface.toggleAwakeLane() }

                )

                HeroLaneCard(

                    eyebrow: "Connectivity",

                    title: "Hotspot helper",

                    caption: "Light probes so tethered networks are less likely to drop when idle.",

                    icon: "dot.radiowaves.left.and.right",

                    isOn: surface.connectivityEnabled,

                    onToggle: { surface.toggleConnectivityLane() }

                )

            }

            sessionLimitationsCallout

            timersCard

        }

        .frame(maxWidth: .infinity, alignment: .leading)

        switch style {

        case .standalone:

            ScrollView { stack }

        case .embedded:

            stack

        }

    }

    private var sessionLimitationsCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LID CLOSED AND AGENTS")
                .font(.mollyCardEyebrow())
                .foregroundStyle(.tertiary)
                .tracking(0.6)
            Text(
                "Awake blocks idle sleep while it is on. Closing the notebook lid can still put the Mac to sleep, depending on power and displays — reliable clamshell use usually means AC power plus an external display. Molly cannot override every hardware and macOS sleep path."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Text(
                "Session presets (30 minutes, 2 hours, 4 hours) turn Awake off when the countdown ends. If you step away longer than the preset, choose Manual so Molly does not release the lane early."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .mollyCard()
    }

    private var timersCard: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("SESSION TIMER")

                .font(.mollyCardEyebrow())

                .foregroundStyle(.tertiary)

                .tracking(0.6)

            Text("Pick a preset")

                .font(.mollySectionTitle())

            Text("We’ll mirror your Awake countdown here so you always know when lanes wind down.")

                .font(.callout)

                .foregroundStyle(.secondary)

            Picker("Preset", selection: Binding<MollyTimerPreset>(

                get: { surface.timerPreset },

                set: { surface.applyTimerPreset($0) }

            )) {

                ForEach(MollyTimerPreset.allCases) {

                    Text($0.menuTitle)

                        .tag($0)

                }

            }

            .pickerStyle(.segmented)

            Toggle("When Awake ends, turn Connectivity off too", isOn: Binding(

                get: { surface.mirrorTimers },

                set: { surface.mirrorTimers = $0 }

            ))

            Divider()

                .opacity(0.35)

            Text(surface.countdownSubtitle)

                .font(.title3.weight(.medium).monospacedDigit())

                .foregroundStyle(MollyTheme.ColorToken.accent.resolve(for: scheme))

        }

        .mollyCard()

    }

}

private struct HeroLaneCard: View {

    @Environment(\.colorScheme) private var scheme

    let eyebrow: String

    let title: String

    let caption: String

    let icon: String

    let isOn: Bool

    let onToggle: () -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                ZStack {

                    Circle()

                        .fill(MollyTheme.ColorToken.accentSoft.resolve(for: scheme).opacity(scheme == .dark ? 0.4 : 0.65))

                        .frame(width: 46, height: 46)

                    Image(systemName: icon)

                        .font(.system(size: 19, weight: .semibold))

                        .foregroundStyle(MollyTheme.ColorToken.accent.resolve(for: scheme))

                }

                Spacer(minLength: 0)

                Toggle("", isOn: Binding(

                    get: { isOn },

                    set: { newValue in

                        if newValue != isOn { onToggle() }

                    }

                ))

                .labelsHidden()

                .toggleStyle(.switch)

                .tint(MollyTheme.ColorToken.accent.resolve(for: scheme))

            }

            Text(eyebrow.uppercased())

                .font(.mollyCardEyebrow())

                .foregroundStyle(.tertiary)

                .tracking(0.6)

            Text(isOn ? "On" : "Off")

                .font(.mollyHeroMetric())

                .foregroundStyle(isOn ? MollyTheme.ColorToken.accent.resolve(for: scheme) : .secondary)

            Text(title)

                .font(.mollySectionTitle())

            Text(caption)

                .font(.callout)

                .foregroundStyle(.secondary)

                .fixedSize(horizontal: false, vertical: true)

        }

        .mollyCard()

    }

}

// MARK: - Shared header

private struct PageHeader: View {

    let title: String

    let subtitle: String

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(title)

                .font(.mollyPageTitle())

            Text(subtitle)

                .font(.body)

                .foregroundStyle(.secondary)

                .fixedSize(horizontal: false, vertical: true)

        }

    }

}

// MARK: - Connectivity

private struct ConnectivityPane: View {

    @ObservedObject var probes: ConnectivityLaneEngine

    @ObservedObject var pilot: MollySessionController

    var style: DashboardPaneStyle = .standalone

    var body: some View {

        let stack = VStack(alignment: .leading, spacing: style == .embedded ? 16 : 24) {

            if style == .standalone {

                PageHeader(

                    title: "Connectivity",

                    subtitle: "Live telemetry from the keepalive lane — calm typography, no faux dashboards."

                )

            }

            LazyVGrid(

                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],

                spacing: 14

            ) {

                WisprMetricTile(title: "Summary", value: probes.summary)

                WisprMetricTile(

                    title: "Lane",

                    value: probes.laneEnabled ? "Armed" : "Idle"

                )

                WisprMetricTile(title: "Success streak", value: "\(probes.successes)", monospacedDigits: true)

                WisprMetricTile(title: "Miss streak", value: "\(probes.failures)", monospacedDigits: true)

            }

            if let ms = probes.lastRTTmilliseconds {

                WisprMetricTile(

                    title: "Last RTT (approx.)",

                    value: String(format: "%.1f ms", ms),

                    monospacedDigits: true

                )

            }

            VStack(alignment: .leading, spacing: 14) {

                datumRow(

                    title: "Network path",

                    detail: probes.networkPathHealthy ? "Satisfied route" : "Paused — no path"

                )

                if let next = probes.nextScheduledAt {

                    datumRow(

                        title: "Next probe",

                        detail: RelativeDateTimeFormatter().localizedString(for: next, relativeTo: Date())

                    )

                }

            }

            .mollyCard()

            InsightCallout(kind: pilot.lowPowerModeActive

                ? "Low Power Mode can make radios conservative. Flip it off briefly if probes look sleepy."

                : "Radios look steady — macOS and Molly are getting along.")

        }

        .frame(maxWidth: .infinity, alignment: .leading)

        switch style {

        case .standalone:

            ScrollView { stack }

        case .embedded:

            stack

        }

    }

    private func datumRow(title: String, detail: String) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title.uppercased())

                .font(.mollyCardEyebrow())

                .foregroundStyle(.tertiary)

                .tracking(0.5)

            Text(detail)

                .font(.body)

        }

    }

}

private struct WisprMetricTile: View {

    let title: String

    let value: String

    var monospacedDigits: Bool = false

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(title.uppercased())

                .font(.mollyCardEyebrow())

                .foregroundStyle(.tertiary)

                .tracking(0.5)

            Text(value)

                .font(monospacedDigits ? .title2.weight(.semibold).monospacedDigit() : .title2.weight(.semibold))

                .foregroundStyle(.primary)

                .lineLimit(3)

                .minimumScaleFactor(0.75)

        }

        .frame(maxWidth: .infinity, alignment: .leading)

        .mollyCard()

    }

}

// MARK: - Insights

private struct InsightPane: View {

    @ObservedObject var surface: MollySessionController

    var style: DashboardPaneStyle = .standalone

    var body: some View {

        let stack = VStack(alignment: .leading, spacing: style == .embedded ? 14 : 22) {

            if style == .standalone {

                PageHeader(

                    title: "Insights",

                    subtitle: "Small tiles that mirror Wispr’s glanceable cards — everything is local to this Mac."

                )

            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {

                chip(title: "Awake", detail: surface.awakeEnabled ? "Asserting idle sleep hold" : "Resting")

                chip(title: "Connectivity", detail: surface.connectivityEnabled ? "Probes in rhythm" : "Paused")

                chip(title: "Distribution", detail: surface.skuSummaryLine)

                chip(title: "Timers", detail: surface.countdownSubtitle)

            }

        }

        .frame(maxWidth: .infinity, alignment: .leading)

        switch style {

        case .standalone:

            ScrollView { stack }

        case .embedded:

            stack

        }

    }

    private func chip(title: String, detail: String) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(title.uppercased())

                .font(.mollyCardEyebrow())

                .foregroundStyle(.tertiary)

                .tracking(0.5)

            Text(detail)

                .font(.body)

                .foregroundStyle(.primary)

        }

        .padding(20)

        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)

        .mollyCard()

    }

}

private struct InsightCallout: View {

    let kind: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        Text(kind)

            .foregroundStyle(Color.primary)

            .font(.callout)

            .padding(18)

            .frame(maxWidth: .infinity, alignment: .leading)

            .background(

                RoundedRectangle(cornerRadius: 16, style: .continuous)

                    .fill(MollyTheme.ColorToken.calloutFill.resolve(for: scheme))

            )

            .overlay(

                RoundedRectangle(cornerRadius: 16, style: .continuous)

                    .strokeBorder(MollyTheme.ColorToken.border.resolve(for: scheme), lineWidth: 1)

            )

    }

}

// MARK: - Logs

private struct LogsPane: View {

    @ObservedObject var journal: MollyLogStore

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        VStack(alignment: .leading, spacing: 18) {

            HStack(alignment: .top, spacing: 12) {

                PageHeader(

                    title: "Log",

                    subtitle: "Rolling JSON Lines on disk — export with the button above the list or ⌘E."

                )

                .frame(maxWidth: .infinity, alignment: .leading)

                Button {

                    journal.exportPlaintextJSONLines()

                } label: {

                    Image(systemName: "square.and.arrow.up")

                }

                .buttonStyle(.borderless)

                .controlSize(.small)

                .imageScale(.small)

                .help("Export JSON Lines")

                .keyboardShortcut("e", modifiers: .command)

                .tint(MollyTheme.ColorToken.accent.resolve(for: scheme))

                .accessibilityLabel("Export log")

            }

            Text(MollyActivityLogLocation.jsonlFileURL.path)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            List(journal.entries) { row in

                VStack(alignment: .leading, spacing: 6) {

                    Text(row.iso8601UTC)

                        .font(.caption.monospaced())

                        .foregroundStyle(.secondary)

                        .frame(maxWidth: .infinity, alignment: .leading)

                        .lineLimit(1)

                        .truncationMode(.tail)

                        .textSelection(.enabled)

                    Text(row.message)

                        .font(.callout)

                        .frame(maxWidth: .infinity, alignment: .leading)

                        .lineLimit(4)

                        .truncationMode(.tail)

                        .textSelection(.enabled)

                    Text(row.metaJSON)

                        .font(.caption2.monospaced())

                        .foregroundStyle(.tertiary)

                        .frame(maxWidth: .infinity, alignment: .leading)

                        .lineLimit(4)

                        .truncationMode(.middle)

                        .textSelection(.enabled)

                }

                .frame(maxWidth: .infinity, alignment: .leading)

                .padding(.vertical, 4)

            }

            .frame(maxWidth: .infinity, maxHeight: .infinity)

            .scrollContentBackground(.hidden)

            .background(

                RoundedRectangle(cornerRadius: 16, style: .continuous)

                    .fill(MollyTheme.ColorToken.card.resolve(for: scheme))

            )

            .overlay(

                RoundedRectangle(cornerRadius: 16, style: .continuous)

                    .strokeBorder(MollyTheme.ColorToken.border.resolve(for: scheme), lineWidth: 1)

            )

            .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.04), radius: 12, y: 4)

        }

        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    }

}

// MARK: - Settings + About (preferences)

private struct PreferencesPane: View {

    @ObservedObject var surface: MollySessionController

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 18) {

                PageHeader(

                    title: "Settings",

                    subtitle: "On-device preferences and a short introduction to Molly."

                )

                SettingsPane(surface: surface, style: .embedded)

                GroupBox {

                    VStack(alignment: .leading, spacing: 10) {

                        Text("About Molly")

                            .font(.mollySectionTitle())

                        AboutMollyNarrative()

                    }

                    .frame(maxWidth: .infinity, alignment: .leading)

                }

            }

            .frame(maxWidth: .infinity, alignment: .leading)

        }

    }

}

private struct AboutMollyNarrative: View {

    var body: some View {

        Text("""

        Molly lives in your menu bar and handles two everyday headaches: keeping workloads from \

        idling the system asleep, and coaxing tethered networks to stay routed.



        Everything runs locally — JSON Lines on disk, no cloud log pipeline in v1.



        The capsule glyph is a nod to helpful packaging, not anything clinical.

        """)

            .font(.body)

            .foregroundStyle(.secondary)

            .lineSpacing(5)

    }

}

// MARK: - Settings

private struct SettingsPane: View {

    @ObservedObject var surface: MollySessionController

    @Environment(\.colorScheme) private var scheme

    @AppStorage(MollyPreferenceKeys.appearance) private var appearanceStore: String = MollyAppearance.system.rawValue

    @State private var launchAtLoginCached = UserDefaults.standard.bool(forKey: MollyPreferenceKeys.launchAtLogin)

    var style: DashboardPaneStyle = .standalone

    var body: some View {

        let formBlock = VStack(alignment: .leading, spacing: style == .embedded ? 14 : 22) {

            if style == .standalone {

                PageHeader(

                    title: "Settings",

                    subtitle: "Everything here stays on-device — just the essentials."

                )

            }

            Form {

                Section("Appearance") {

                    Picker("Window theme", selection: $appearanceStore) {

                        ForEach(MollyAppearance.allCases) { mode in

                            Text(mode.title).tag(mode.rawValue)

                        }

                    }

                    .pickerStyle(.segmented)

                    Text("Light keeps the bright Wispr-style canvas even when macOS is in Dark Mode.")

                        .font(.caption)

                        .foregroundStyle(.secondary)

                }

                Toggle(

                    "Gentle notifications",

                    isOn: Binding(

                        get: { surface.notificationsEnabled },

                        set: { surface.notificationsEnabled = $0 }

                    )

                )

                Toggle(isOn: Binding(

                    get: { launchAtLoginCached },

                    set: { tapped in

                        launchAtLoginCached = tapped

                        surface.applyLaunchRegistrationToggle(tapped)

                    }

                )) {

                    Text("Open Molly at login")

                }

                Section("About this build") {

                    Text(MollySKU.connectivityNarrative)

                        .foregroundStyle(.secondary)

                        .font(.callout)

                }

            }

            .formStyle(.grouped)

            .frame(maxWidth: style == .embedded ? .infinity : 520)

            .scrollContentBackground(.hidden)

            .background(MollyTheme.ColorToken.card.resolve(for: scheme))

            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            .overlay(

                RoundedRectangle(cornerRadius: 16, style: .continuous)

                    .strokeBorder(MollyTheme.ColorToken.border.resolve(for: scheme), lineWidth: 1)

            )

            .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.04), radius: 12, y: 4)

        }

        .frame(maxWidth: .infinity, alignment: .leading)

        Group {

            switch style {

            case .standalone:

                ScrollView { formBlock }

            case .embedded:

                formBlock

            }

        }

        .task {

            launchAtLoginCached = LaunchRegistration.readSystemFlag()

        }

    }

}
