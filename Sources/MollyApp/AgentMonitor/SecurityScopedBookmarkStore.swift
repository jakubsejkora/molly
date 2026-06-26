import AppKit
import Foundation

@MainActor
final class SecurityScopedBookmarkStore: ObservableObject {

    @Published private(set) var grantedTools: Set<AgentToolKind> = []

    private var resolvedURLs: [AgentToolKind: URL] = [:]
    private var accessCounts: [AgentToolKind: Int] = [:]

    init() {
        reloadFromDefaults()
    }

    func reloadFromDefaults() {
        stopAllAccess()
        resolvedURLs.removeAll()
        grantedTools.removeAll()

        for tool in AgentToolKind.allCases {
            guard let data = UserDefaults.standard.data(forKey: tool.preferenceBookmarkKey) else { continue }
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { continue }

            if stale, let refreshed = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(refreshed, forKey: tool.preferenceBookmarkKey)
            }

            resolvedURLs[tool] = url
            grantedTools.insert(tool)
        }
    }

    func rootURL(for tool: AgentToolKind) -> URL? {
        resolvedURLs[tool]
    }

    func withAccess<T>(to tool: AgentToolKind, perform work: (URL) throws -> T) rethrows -> T? {
        guard let url = resolvedURLs[tool] else { return nil }
        let started = url.startAccessingSecurityScopedResource()
        if started {
            accessCounts[tool, default: 0] += 1
        }
        defer {
            if started {
                accessCounts[tool, default: 1] -= 1
                if accessCounts[tool, default: 0] <= 0 {
                    accessCounts[tool] = nil
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        return try work(url)
    }

    func storeBookmark(from url: URL, for tool: AgentToolKind) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: tool.preferenceBookmarkKey)
        reloadFromDefaults()
    }

    func clearBookmark(for tool: AgentToolKind) {
        UserDefaults.standard.removeObject(forKey: tool.preferenceBookmarkKey)
        reloadFromDefaults()
    }

    func presentFolderPicker(for tool: AgentToolKind) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Grant Access"
        panel.message = "Choose your \(tool.suggestedFolderName) folder so Molly can read active \(tool.displayName) sessions."
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try storeBookmark(from: url, for: tool)
        } catch {
            NSLog("Molly: failed to store bookmark for \(tool.rawValue): \(error)")
        }
    }

    private func stopAllAccess() {
        for (tool, count) in accessCounts where count > 0 {
            resolvedURLs[tool]?.stopAccessingSecurityScopedResource()
        }
        accessCounts.removeAll()
    }
}
