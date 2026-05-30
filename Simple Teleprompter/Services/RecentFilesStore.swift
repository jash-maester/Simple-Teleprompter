//
//  RecentFilesStore.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import Foundation
import Observation
import OSLog

/// Persistent list of recently-opened script URLs, exposed through the
/// File → Open Recent menu.
///
/// Because the app is sandboxed (`com.apple.security.files.user-selected.read-only`),
/// the only way to *re-open* a remembered URL on a future launch is via a
/// **security-scoped bookmark**. Creating one of those usually requires
/// the `com.apple.security.files.bookmarks.app-scope` entitlement; if
/// that's missing we still keep the entry in memory for this session, we
/// just can't persist it across relaunches.
@Observable
@MainActor
final class RecentFilesStore {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SimpleTeleprompter",
        category: "RecentFiles"
    )

    private static let defaultsKey = "RecentScripts"
    private static let maxEntries = 10

    /// One file in the recents list.
    ///
    /// `bookmark` is `nil` if security-scoped bookmark creation failed at
    /// `add` time — the entry remains usable in the current session
    /// (via the captured `url`) but won't survive relaunch.
    struct Entry: Identifiable, Hashable {
        var id: URL { url }
        let url: URL
        let bookmark: Data?
    }

    private(set) var entries: [Entry] = []

    init() {
        reload()
        Self.logger.info("RecentFilesStore loaded \(self.entries.count, privacy: .public) entry(s) from defaults")
    }

    /// Prepends `url` (deduplicated by path). Caller must already be
    /// inside `startAccessingSecurityScopedResource` for `url` so the
    /// bookmark captures with read permission.
    func add(_ url: URL) {
        let bookmark: Data?
        do {
            // The read-only flag is required because our entitlement is
            // `com.apple.security.files.user-selected.read-only`. Without
            // it `.withSecurityScope` tries to capture read-write access
            // and `open()` fails with EPERM under the sandbox.
            bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            Self.logger.info("Captured bookmark for \(url.lastPathComponent, privacy: .public)")
        } catch {
            Self.logger.warning("Bookmark creation failed for \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            bookmark = nil
        }

        entries.removeAll { $0.url.standardizedFileURL == url.standardizedFileURL }
        entries.insert(Entry(url: url, bookmark: bookmark), at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        persist()
        Self.logger.info("Recent count now \(self.entries.count, privacy: .public)")
    }

    func remove(_ url: URL) {
        let target = url.standardizedFileURL
        entries.removeAll { $0.url.standardizedFileURL == target }
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
        Self.logger.info("Recents cleared")
    }

    /// Resolves a remembered entry to a usable URL. If a bookmark exists
    /// we resolve it (and refresh on staleness); otherwise we fall back
    /// to the in-memory URL captured at `add` time, which works in the
    /// session it was added but not afterwards.
    func resolve(_ entry: Entry) -> URL? {
        guard let bookmark = entry.bookmark else {
            // Session-only entry. Trust the captured URL.
            return FileManager.default.fileExists(atPath: entry.url.path) ? entry.url : nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard FileManager.default.fileExists(atPath: url.path) else {
                Self.logger.info("Recent file missing on disk: \(url.lastPathComponent, privacy: .public)")
                remove(entry.url)
                return nil
            }
            if isStale {
                Self.logger.info("Refreshing stale bookmark for \(url.lastPathComponent, privacy: .public)")
                refresh(entry: entry, with: url)
            }
            return url
        } catch {
            Self.logger.error("Bookmark resolve failed: \(String(describing: error), privacy: .public)")
            remove(entry.url)
            return nil
        }
    }

    // MARK: Private

    private func reload() {
        guard let raw = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [Data] else { return }
        var loaded: [Entry] = []
        for data in raw {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            loaded.append(Entry(url: url, bookmark: data))
        }
        entries = loaded
    }

    private func persist() {
        // Only entries with valid bookmarks are saved across launches.
        let datas = entries.compactMap(\.bookmark)
        UserDefaults.standard.set(datas, forKey: Self.defaultsKey)
    }

    private func refresh(entry: Entry, with url: URL) {
        guard let idx = entries.firstIndex(of: entry) else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let fresh = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        entries[idx] = Entry(url: url, bookmark: fresh)
        persist()
    }
}
