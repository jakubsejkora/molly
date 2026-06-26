import Foundation

enum CursorTerminalReader {

    struct RawTerminal: Sendable {
        let pid: Int32
        let cwd: String?
        let activeCommand: String?
        let lastExitCode: Int?
        let workspacePath: String
        let lastUpdated: Date
    }

    struct RawTranscript: Sendable {
        let sessionID: String
        let workspacePath: String
        let lastUpdated: Date
    }

    static func readTerminals(at projectsRoot: URL) -> [RawTerminal] {
        guard let workspaces = try? FileManager.default.contentsOfDirectory(
            at: projectsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [RawTerminal] = []
        for workspace in workspaces {
            let terminalsDir = workspace.appendingPathComponent("terminals", isDirectory: true)
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: terminalsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files where file.pathExtension == "txt" {
                guard let parsed = parseTerminalFile(file, workspacePath: workspace.path) else { continue }
                results.append(parsed)
            }
        }
        return results
    }

    static func readRecentTranscripts(at projectsRoot: URL, maxAge: TimeInterval = 900) -> [RawTranscript] {
        guard let workspaces = try? FileManager.default.contentsOfDirectory(
            at: projectsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let cutoff = Date().addingTimeInterval(-maxAge)
        var results: [RawTranscript] = []

        for workspace in workspaces {
            let transcriptsRoot = workspace.appendingPathComponent("agent-transcripts", isDirectory: true)
            guard let sessionFolders = try? FileManager.default.contentsOfDirectory(
                at: transcriptsRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for sessionFolder in sessionFolders {
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: sessionFolder,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for file in files where file.pathExtension == "jsonl" || file.pathExtension == "txt" {
                    let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    guard mtime >= cutoff else { continue }
                    results.append(RawTranscript(
                        sessionID: sessionFolder.lastPathComponent,
                        workspacePath: decodeWorkspacePath(workspace.lastPathComponent),
                        lastUpdated: mtime
                    ))
                }
            }
        }
        return results
    }

    private static func parseTerminalFile(_ url: URL, workspacePath: String) -> RawTerminal? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first == "---" else { return nil }

        var pid: Int32 = -1
        var cwd: String?
        var activeCommand: String?
        var lastExitCode: Int?

        for line in lines.dropFirst() {
            if line == "---" { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("pid:") {
                pid = Int32(trimmed.replacingOccurrences(of: "pid:", with: "").trimmingCharacters(in: .whitespaces)) ?? -1
            } else if trimmed.hasPrefix("cwd:") {
                cwd = trimmed.replacingOccurrences(of: "cwd:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("active_command:") {
                activeCommand = trimmed.replacingOccurrences(of: "active_command:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("last_exit_code:") {
                lastExitCode = Int(trimmed.replacingOccurrences(of: "last_exit_code:", with: "").trimmingCharacters(in: .whitespaces))
            }
        }

        guard pid > 0 else { return nil }
        let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()

        return RawTerminal(
            pid: pid,
            cwd: cwd,
            activeCommand: activeCommand?.isEmpty == true ? nil : activeCommand,
            lastExitCode: lastExitCode,
            workspacePath: decodeWorkspacePath(workspacePath),
            lastUpdated: mtime
        )
    }

    private static func decodeWorkspacePath(_ encoded: String) -> String {
        if encoded.hasPrefix("Users-") || encoded.contains("-") {
            return "/" + encoded.replacingOccurrences(of: "-", with: "/")
        }
        return encoded
    }
}
