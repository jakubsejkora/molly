import Foundation

enum ProcessScanner {

    static func scan() -> [AgentToolKind: [ProcessRecord]] {
        let processes = listProcesses()
        var grouped: [AgentToolKind: [ProcessRecord]] = [:]
        for tool in AgentToolKind.allCases {
            grouped[tool] = []
        }

        for process in processes {
            if let tool = classify(process.command) {
                grouped[tool, default: []].append(process)
            }
        }
        return grouped
    }

    private static func listProcesses() -> [ProcessRecord] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-ax", "-o", "pid=,etime=,command="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        return text
            .split(whereSeparator: \.isNewline)
            .compactMap(parseLine)
    }

    private static func parseLine(_ line: Substring) -> ProcessRecord? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(maxSplits: 2, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard parts.count >= 2,
              let pid = Int32(parts[0])
        else { return nil }

        let elapsed = parseElapsed(String(parts[1]))
        let command = parts.count >= 3 ? String(parts[2]) : String(parts[1])
        return ProcessRecord(pid: pid, command: command, elapsedSeconds: elapsed)
    }

    private static func parseElapsed(_ token: String) -> Int {
        if token.contains("-") {
            let dayParts = token.split(separator: "-", maxSplits: 1)
            let days = Int(dayParts[0]) ?? 0
            let remainder = dayParts.count > 1 ? String(dayParts[1]) : "0"
            return days * 86_400 + parseClock(remainder)
        }
        return parseClock(token)
    }

    private static func parseClock(_ token: String) -> Int {
        let chunks = token.split(separator: ":").map(String.init)
        guard !chunks.isEmpty else { return 0 }

        if chunks.count == 3 {
            let hours = Int(chunks[0]) ?? 0
            let minutes = Int(chunks[1]) ?? 0
            let seconds = Int(chunks[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        }
        if chunks.count == 2 {
            let minutes = Int(chunks[0]) ?? 0
            let seconds = Int(chunks[1]) ?? 0
            return minutes * 60 + seconds
        }
        return Int(chunks[0]) ?? 0
    }

    private static func classify(_ command: String) -> AgentToolKind? {
        let lower = command.lowercased()

        if lower.contains("/claude") || lower.hasSuffix(" claude") || lower.contains(" claude ") {
            return .claudeCode
        }
        if lower.contains("cursor.app") || lower.contains("/cursor ") || lower.contains(" cursor-agent") {
            return .cursor
        }
        if lower.contains("/codex") || lower.hasSuffix(" codex") || lower.contains(" codex ") {
            return .codex
        }
        return nil
    }
}
