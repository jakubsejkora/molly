import Foundation

enum ClaudeSessionRegistryReader {

    struct RawSession: Sendable {
        let pid: Int32
        let sessionID: String
        let cwd: String?
        let status: AgentRunStatus
        let name: String?
        let startedAt: Date?
    }

    struct RawJob: Sendable {
        let jobID: String
        let sessionID: String?
        let cwd: String?
        let state: AgentRunStatus
        let name: String?
        let updatedAt: Date?
    }

    struct RawSubagent: Sendable {
        let agentID: String
        let sessionID: String
        let displayName: String
        let lastUpdated: Date
    }

    static func readSessions(at claudeRoot: URL) -> [RawSession] {
        let sessionsDir = claudeRoot.appendingPathComponent("sessions", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { parseSessionFile($0) }
    }

    static func readJobs(at claudeRoot: URL) -> [RawJob] {
        let jobsDir = claudeRoot.appendingPathComponent("jobs", isDirectory: true)
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: jobsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return folders.compactMap { folder in
            let stateURL = folder.appendingPathComponent("state.json")
            guard FileManager.default.fileExists(atPath: stateURL.path) else { return nil }
            return parseJobFile(stateURL, jobID: folder.lastPathComponent)
        }
    }

    static func readSubagents(at claudeRoot: URL) -> [RawSubagent] {
        let projectsDir = claudeRoot.appendingPathComponent("projects", isDirectory: true)
        guard let projectFolders = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [RawSubagent] = []
        let agentNames = loadAgentDefinitionNames(at: claudeRoot)

        for projectFolder in projectFolders {
            guard let sessionFiles = try? FileManager.default.contentsOfDirectory(
                at: projectFolder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for sessionFile in sessionFiles where sessionFile.pathExtension == "jsonl" {
                let sessionID = sessionFile.deletingPathExtension().lastPathComponent
                let subagentsDir = projectFolder
                    .appendingPathComponent(sessionID, isDirectory: true)
                    .appendingPathComponent("subagents", isDirectory: true)
                guard let subagentFiles = try? FileManager.default.contentsOfDirectory(
                    at: subagentsDir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for subagentFile in subagentFiles where subagentFile.pathExtension == "jsonl" {
                    let agentID = subagentFile.deletingPathExtension().lastPathComponent
                        .replacingOccurrences(of: "agent-", with: "")
                    let mtime = (try? subagentFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let resolvedName = resolveSubagentName(
                        agentID: agentID,
                        sessionFile: sessionFile,
                        definitions: agentNames
                    )
                    results.append(RawSubagent(
                        agentID: agentID,
                        sessionID: sessionID,
                        displayName: resolvedName,
                        lastUpdated: mtime
                    ))
                }
            }
        }
        return results
    }

    private static func parseSessionFile(_ url: URL) -> RawSession? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let pid = Int32(json["pid"] as? Int ?? Int(url.deletingPathExtension().lastPathComponent) ?? 0)
        guard pid > 0 else { return nil }

        let sessionID = json["sessionId"] as? String ?? url.deletingPathExtension().lastPathComponent
        let cwd = json["cwd"] as? String
        let status = AgentRunStatus(rawValue: json["status"] as? String ?? "") ?? .unknown
        let name = json["name"] as? String
        let startedAt = parseDate(json["startedAt"])

        return RawSession(
            pid: pid,
            sessionID: sessionID,
            cwd: cwd,
            status: status == .unknown ? .running : status,
            name: name,
            startedAt: startedAt
        )
    }

    private static func parseJobFile(_ url: URL, jobID: String) -> RawJob? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let stateRaw = json["state"] as? String ?? "running"
        let status: AgentRunStatus
        switch stateRaw {
        case "running": status = .running
        case "done", "completed": status = .idle
        case "errored", "error": status = .waiting
        default: status = .unknown
        }

        return RawJob(
            jobID: jobID,
            sessionID: json["sessionId"] as? String,
            cwd: json["cwd"] as? String ?? json["originCwd"] as? String,
            state: status,
            name: json["intent"] as? String ?? json["name"] as? String,
            updatedAt: parseDate(json["updatedAt"]) ?? parseDate(json["createdAt"])
        )
    }

    private static func loadAgentDefinitionNames(at claudeRoot: URL) -> [String: String] {
        var map: [String: String] = [:]
        let searchRoots = [
            claudeRoot.appendingPathComponent("agents", isDirectory: true),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".claude/agents", isDirectory: true)
        ]

        for root in searchRoots {
            guard let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "md" {
                if let text = try? String(contentsOf: file, encoding: .utf8),
                   let name = parseFrontmatterName(text) {
                    map[file.deletingPathExtension().lastPathComponent] = name
                }
            }
        }
        return map
    }

    private static func parseFrontmatterName(_ markdown: String) -> String? {
        guard markdown.hasPrefix("---") else { return nil }
        let lines = markdown.split(whereSeparator: \.isNewline)
        guard lines.count >= 3, lines[0] == "---" else { return nil }
        for line in lines.dropFirst() {
            if line == "---" { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") {
                return trimmed.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func resolveSubagentName(
        agentID: String,
        sessionFile: URL,
        definitions: [String: String]
    ) -> String {
        if let tailName = scanTranscriptForSubagentName(sessionFile: sessionFile, agentID: agentID) {
            return tailName
        }
        for (key, value) in definitions where agentID.contains(key) || key.contains(agentID) {
            return value
        }
        if agentID.count > 8 {
            return String(agentID.prefix(8))
        }
        return agentID
    }

    private static func scanTranscriptForSubagentName(sessionFile: URL, agentID: String) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: sessionFile) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }

        for line in text.split(whereSeparator: \.isNewline).suffix(80) {
            guard let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
            let blob = String(describing: json)
            guard blob.contains(agentID) || blob.contains("subagent") else { continue }
            if let name = json["name"] as? String, !name.isEmpty { return name }
            if let content = json["content"] as? String, content.contains("client-builder") { return "client-builder" }
        }
        return nil
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
