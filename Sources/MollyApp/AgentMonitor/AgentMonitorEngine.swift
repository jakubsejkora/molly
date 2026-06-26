import Combine
import Foundation

@MainActor
final class AgentMonitorEngine: ObservableObject {

    @Published private(set) var snapshot: AgentMonitorSnapshot = .empty

    let bookmarks = SecurityScopedBookmarkStore()

    private weak var sink: MollyLogging?
    private var pollTask: Task<Void, Never>?

    init(logging: MollyLogging?) {
        sink = logging
    }

    func attachLogging(_ logger: MollyLogging?) {
        sink = logger
    }

    func startMonitoring() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performScan()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        Task { await performScan() }
    }

    func stopMonitoring() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refreshNow() {
        Task { await performScan() }
    }

    func requestFolderAccess(for tool: AgentToolKind) {
        bookmarks.presentFolderPicker(for: tool)
        refreshNow()
    }

    func revokeFolderAccess(for tool: AgentToolKind) {
        bookmarks.clearBookmark(for: tool)
        refreshNow()
    }

    private func performScan() async {
        let processGroups = await Task.detached(priority: .utility) {
            ProcessScanner.scan()
        }.value

        var sessions: [AgentSessionSnapshot] = []
        var accessGranted = bookmarks.grantedTools
        let now = Date()

        if let claudeRoot = bookmarks.rootURL(for: .claudeCode) {
            let claudeSessions = bookmarks.withAccess(to: .claudeCode) { root in
                Self.scanClaude(at: root, processes: processGroups[.claudeCode] ?? [])
            } ?? []
            sessions.append(contentsOf: claudeSessions)
        }

        if let cursorRoot = bookmarks.rootURL(for: .cursor) {
            let cursorSessions = bookmarks.withAccess(to: .cursor) { root in
                Self.scanCursor(at: root, processes: processGroups[.cursor] ?? [])
            } ?? []
            sessions.append(contentsOf: cursorSessions)
        }

        if let codexRoot = bookmarks.rootURL(for: .codex) {
            let codexSessions = bookmarks.withAccess(to: .codex) { root in
                Self.scanCodex(at: root, processes: processGroups[.codex] ?? [])
            } ?? []
            sessions.append(contentsOf: codexSessions)
        }

        var tools: [AgentToolKind: AgentToolSummary] = [:]
        for tool in AgentToolKind.allCases {
            let processCount = processGroups[tool]?.count ?? 0
            let sessionCount = sessions.filter { $0.tool == tool }.count
            tools[tool] = AgentToolSummary(processCount: processCount, sessionCount: sessionCount)
        }

        let merged = AgentMonitorSnapshot(
            tools: tools,
            sessions: sessions.sorted { lhs, rhs in
                if lhs.tool != rhs.tool { return lhs.tool.rawValue < rhs.tool.rawValue }
                if lhs.role != rhs.role { return lhs.role == .main && rhs.role != .main }
                return lhs.displayName < rhs.displayName
            },
            accessGranted: accessGranted,
            lastScanAt: now
        )

        logTransitions(from: snapshot, to: merged)
        snapshot = merged
    }

    nonisolated private static func scanClaude(at root: URL, processes: [ProcessRecord]) -> [AgentSessionSnapshot] {
        let liveSessions = ClaudeSessionRegistryReader.readSessions(at: root)
        let jobs = ClaudeSessionRegistryReader.readJobs(at: root)
        let subagents = ClaudeSessionRegistryReader.readSubagents(at: root)
        let now = Date()

        var results: [AgentSessionSnapshot] = []

        for session in liveSessions {
            let displayName = session.name?.isEmpty == false ? session.name! : "main"
            results.append(AgentSessionSnapshot(
                id: "claude:\(session.sessionID)",
                tool: .claudeCode,
                displayName: displayName,
                role: .main,
                cwd: session.cwd,
                status: session.status,
                startedAt: session.startedAt,
                pid: session.pid,
                parentSessionID: nil,
                detailLine: session.cwd,
                lastUpdated: now
            ))
        }

        for job in jobs where job.state != .idle {
            results.append(AgentSessionSnapshot(
                id: "claude-job:\(job.jobID)",
                tool: .claudeCode,
                displayName: job.name ?? "background",
                role: .background,
                cwd: job.cwd,
                status: job.state,
                startedAt: job.updatedAt,
                pid: nil,
                parentSessionID: job.sessionID,
                detailLine: job.cwd,
                lastUpdated: now
            ))
        }

        let recentCutoff = now.addingTimeInterval(-900)
        for subagent in subagents where subagent.lastUpdated >= recentCutoff {
            results.append(AgentSessionSnapshot(
                id: "claude-sub:\(subagent.sessionID):\(subagent.agentID)",
                tool: .claudeCode,
                displayName: subagent.displayName,
                role: .subagent,
                cwd: nil,
                status: .running,
                startedAt: nil,
                pid: nil,
                parentSessionID: subagent.sessionID,
                detailLine: "Sub-agent",
                lastUpdated: subagent.lastUpdated
            ))
        }

        if results.isEmpty, !processes.isEmpty {
            for process in processes {
                results.append(AgentSessionSnapshot(
                    id: "claude-proc:\(process.pid)",
                    tool: .claudeCode,
                    displayName: "claude",
                    role: .unknown,
                    cwd: nil,
                    status: .running,
                    startedAt: Date().addingTimeInterval(-Double(process.elapsedSeconds)),
                    pid: process.pid,
                    parentSessionID: nil,
                    detailLine: "Grant ~/.claude access for session detail",
                    lastUpdated: now
                ))
            }
        }

        return results
    }

    nonisolated private static func scanCursor(at root: URL, processes: [ProcessRecord]) -> [AgentSessionSnapshot] {
        let terminals = CursorTerminalReader.readTerminals(at: root)
        let transcripts = CursorTerminalReader.readRecentTranscripts(at: root)
        let now = Date()
        var results: [AgentSessionSnapshot] = []
        var seen: Set<String> = []

        for terminal in terminals {
            let id = "cursor-term:\(terminal.pid)"
            seen.insert(id)
            let status: AgentRunStatus = terminal.activeCommand == nil ? .idle : .running
            results.append(AgentSessionSnapshot(
                id: id,
                tool: .cursor,
                displayName: terminal.activeCommand ?? "terminal",
                role: .main,
                cwd: terminal.cwd ?? terminal.workspacePath,
                status: status,
                startedAt: terminal.lastUpdated.addingTimeInterval(-300),
                pid: terminal.pid,
                parentSessionID: nil,
                detailLine: terminal.workspacePath,
                lastUpdated: terminal.lastUpdated
            ))
        }

        for transcript in transcripts {
            let id = "cursor-transcript:\(transcript.sessionID)"
            guard !seen.contains(id) else { continue }
            results.append(AgentSessionSnapshot(
                id: id,
                tool: .cursor,
                displayName: "agent session",
                role: .main,
                cwd: transcript.workspacePath,
                status: .running,
                startedAt: transcript.lastUpdated.addingTimeInterval(-120),
                pid: nil,
                parentSessionID: nil,
                detailLine: transcript.workspacePath,
                lastUpdated: transcript.lastUpdated
            ))
        }

        if results.isEmpty, !processes.isEmpty {
            for process in processes.prefix(3) {
                results.append(AgentSessionSnapshot(
                    id: "cursor-proc:\(process.pid)",
                    tool: .cursor,
                    displayName: "Cursor",
                    role: .unknown,
                    cwd: nil,
                    status: .running,
                    startedAt: Date().addingTimeInterval(-Double(process.elapsedSeconds)),
                    pid: process.pid,
                    parentSessionID: nil,
                    detailLine: "Grant ~/.cursor/projects access for session detail",
                    lastUpdated: now
                ))
            }
        }

        return results
    }

    nonisolated private static func scanCodex(at root: URL, processes: [ProcessRecord]) -> [AgentSessionSnapshot] {
        let threads = CodexThreadReader.readThreads(at: root)
        let now = Date()
        var results: [AgentSessionSnapshot] = []

        for thread in threads {
            results.append(AgentSessionSnapshot(
                id: "codex:\(thread.id)",
                tool: .codex,
                displayName: thread.title ?? "codex thread",
                role: .main,
                cwd: thread.cwd,
                status: .running,
                startedAt: thread.updatedAt,
                pid: nil,
                parentSessionID: nil,
                detailLine: thread.cwd,
                lastUpdated: thread.updatedAt ?? now
            ))
        }

        if results.isEmpty, !processes.isEmpty {
            for process in processes {
                results.append(AgentSessionSnapshot(
                    id: "codex-proc:\(process.pid)",
                    tool: .codex,
                    displayName: "codex",
                    role: .unknown,
                    cwd: nil,
                    status: .running,
                    startedAt: Date().addingTimeInterval(-Double(process.elapsedSeconds)),
                    pid: process.pid,
                    parentSessionID: nil,
                    detailLine: "Grant ~/.codex access for thread detail",
                    lastUpdated: now
                ))
            }
        }

        return results
    }

    private func logTransitions(from previous: AgentMonitorSnapshot, to next: AgentMonitorSnapshot) {
        let previousKeys = Set(previous.sessions.map(\.id))
        let nextKeys = Set(next.sessions.map(\.id))

        for session in next.sessions where !previousKeys.contains(session.id) {
            sink?.append(
                level: .info,
                message: "Agent session started",
                meta: [
                    "tool": session.tool.rawValue,
                    "name": session.displayName,
                    "status": session.status.rawValue
                ]
            )
        }

        for session in previous.sessions where !nextKeys.contains(session.id) {
            sink?.append(
                level: .info,
                message: "Agent session ended",
                meta: [
                    "tool": session.tool.rawValue,
                    "name": session.displayName
                ]
            )
        }

        for session in next.sessions where previousKeys.contains(session.id) {
            guard let old = previous.sessions.first(where: { $0.id == session.id }),
                  old.status != session.status
            else { continue }
            sink?.append(
                level: .info,
                message: "Agent session status changed",
                meta: [
                    "tool": session.tool.rawValue,
                    "name": session.displayName,
                    "from": old.status.rawValue,
                    "to": session.status.rawValue
                ]
            )
            if session.status == .waiting {
                sink?.append(
                    level: .info,
                    message: "Agent waiting for input",
                    meta: [
                        "tool": session.tool.rawValue,
                        "name": session.displayName
                    ]
                )
            }
        }
    }
}
