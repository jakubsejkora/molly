import Foundation
import SQLite3

enum CodexThreadReader {

    struct RawThread: Sendable {
        let id: String
        let title: String?
        let cwd: String?
        let rolloutPath: String?
        let updatedAt: Date?
        let isActive: Bool
    }

    static func readThreads(at codexRoot: URL, activeWithin seconds: TimeInterval = 900) -> [RawThread] {
        let sqliteURL = locateStateDatabase(at: codexRoot)
        guard let sqliteURL else { return [] }

        let tempURL = copyToTemporaryReadableFile(sqliteURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var db: OpaquePointer?
        guard sqlite3_open_v2(tempURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return []
        }
        defer { sqlite3_close(db) }

        let cutoff = Date().addingTimeInterval(-seconds)
        var threads: [RawThread] = []

        let query = """
        SELECT id, title, cwd, rollout_path, updated_at
        FROM threads
        WHERE archived_at IS NULL
        ORDER BY updated_at DESC
        LIMIT 50
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = stringColumn(statement, index: 0) ?? UUID().uuidString
            let title = stringColumn(statement, index: 1)
            let cwd = stringColumn(statement, index: 2)
            let rolloutPath = stringColumn(statement, index: 3)
            let updatedAt = parseSQLiteDate(stringColumn(statement, index: 4))

            let rolloutURL: URL? = {
                guard let rolloutPath else { return nil }
                if rolloutPath.hasPrefix("/") {
                    return URL(fileURLWithPath: rolloutPath)
                }
                return codexRoot.appendingPathComponent(rolloutPath)
            }()
            let rolloutMTime = rolloutURL.flatMap { fileModificationDate($0) }
            let isActive = (updatedAt ?? .distantPast) >= cutoff || (rolloutMTime ?? .distantPast) >= cutoff

            threads.append(RawThread(
                id: id,
                title: title,
                cwd: cwd,
                rolloutPath: rolloutPath,
                updatedAt: updatedAt ?? rolloutMTime,
                isActive: isActive
            ))
        }

        return threads.filter(\.isActive)
    }

    private static func locateStateDatabase(at codexRoot: URL) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(at: codexRoot, includingPropertiesForKeys: nil) else {
            return nil
        }
        return files
            .filter { $0.lastPathComponent.hasPrefix("state_") && $0.pathExtension == "sqlite" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
    }

    private static func copyToTemporaryReadableFile(_ source: URL) -> URL {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("molly-codex-\(UUID().uuidString).sqlite")
        try? FileManager.default.removeItem(at: temp)
        try? FileManager.default.copyItem(at: source, to: temp)
        return temp
    }

    private static func stringColumn(_ statement: OpaquePointer, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let cString = sqlite3_column_text(statement, index)
        else { return nil }
        return String(cString: cString)
    }

    private static func parseSQLiteDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) { return date }

        let sqliteFormatter = DateFormatter()
        sqliteFormatter.locale = Locale(identifier: "en_US_POSIX")
        sqliteFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return sqliteFormatter.date(from: value)
    }

    private static func fileModificationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
