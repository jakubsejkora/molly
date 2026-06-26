import Foundation

enum AgentToolKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case claudeCode
    case cursor
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        }
    }

    var shortLabel: String {
        switch self {
        case .claudeCode: return "Claude"
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        }
    }

    /// Default folder the user should grant for richer session detail.
    var suggestedFolderName: String {
        switch self {
        case .claudeCode: return ".claude"
        case .cursor: return ".cursor/projects"
        case .codex: return ".codex"
        }
    }

    var preferenceBookmarkKey: String {
        switch self {
        case .claudeCode: return MollyPreferenceKeys.agentBookmarkClaude
        case .cursor: return MollyPreferenceKeys.agentBookmarkCursor
        case .codex: return MollyPreferenceKeys.agentBookmarkCodex
        }
    }
}

enum AgentRole: String, Codable, Hashable {
    case main
    case subagent
    case background
    case unknown
}

enum AgentRunStatus: String, Codable, Hashable {
    case busy
    case idle
    case waiting
    case running
    case unknown

    var displayTitle: String {
        switch self {
        case .busy: return "Busy"
        case .idle: return "Idle"
        case .waiting: return "Waiting"
        case .running: return "Running"
        case .unknown: return "Unknown"
        }
    }
}

struct AgentToolSummary: Equatable {
    var processCount: Int = 0
    var sessionCount: Int = 0
    var isRunning: Bool { processCount > 0 || sessionCount > 0 }
}

struct AgentSessionSnapshot: Identifiable, Equatable {
    let id: String
    let tool: AgentToolKind
    let displayName: String
    let role: AgentRole
    let cwd: String?
    let status: AgentRunStatus
    let startedAt: Date?
    let pid: Int32?
    let parentSessionID: String?
    let detailLine: String?
    let lastUpdated: Date

    var elapsedDescription: String? {
        guard let startedAt else { return nil }
        let seconds = Int(Date().timeIntervalSince(startedAt))
        guard seconds >= 0 else { return nil }
        let minutes = seconds / 60
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds % 60)s"
        }
        return "\(seconds)s"
    }
}

struct AgentMonitorSnapshot: Equatable {
    var tools: [AgentToolKind: AgentToolSummary]
    var sessions: [AgentSessionSnapshot]
    var accessGranted: Set<AgentToolKind>
    var lastScanAt: Date

    static let empty = AgentMonitorSnapshot(
        tools: Dictionary(uniqueKeysWithValues: AgentToolKind.allCases.map { ($0, AgentToolSummary()) }),
        sessions: [],
        accessGranted: [],
        lastScanAt: .distantPast
    )

    var activeSessionCount: Int {
        sessions.count
    }

    var waitingSessionCount: Int {
        sessions.filter { $0.status == .waiting }.count
    }

    var summaryLine: String {
        let claude = tools[.claudeCode]?.sessionCount ?? tools[.claudeCode]?.processCount ?? 0
        let cursor = tools[.cursor]?.sessionCount ?? tools[.cursor]?.processCount ?? 0
        let codex = tools[.codex]?.sessionCount ?? tools[.codex]?.processCount ?? 0
        return "Claude \(claude) · Cursor \(cursor) · Codex \(codex)"
    }

    var headlineSummary: String {
        let toolCount = AgentToolKind.allCases.filter { tools[$0]?.isRunning == true }.count
        let waiting = waitingSessionCount
        if activeSessionCount == 0 && toolCount == 0 {
            return "No AI coding tools detected"
        }
        var parts: [String] = []
        if toolCount > 0 {
            parts.append("\(toolCount) tool\(toolCount == 1 ? "" : "s")")
        }
        if activeSessionCount > 0 {
            parts.append("\(activeSessionCount) session\(activeSessionCount == 1 ? "" : "s")")
        }
        if waiting > 0 {
            parts.append("\(waiting) waiting")
        }
        return parts.joined(separator: " · ")
    }
}

struct ProcessRecord: Equatable, Sendable {
    let pid: Int32
    let command: String
    let elapsedSeconds: Int
}

enum AgentMonitorScanInput: Sendable {
    case claudeRoot(URL)
    case cursorProjectsRoot(URL)
    case codexRoot(URL)
}
