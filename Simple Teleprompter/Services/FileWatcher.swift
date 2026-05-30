//
//  FileWatcher.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import Darwin
import Dispatch
import Foundation
import OSLog

/// Watches a single file on disk for content changes and fires a
/// debounced `onChange` callback on the main actor.
///
/// Wraps `DispatchSource.makeFileSystemObjectSource` with a 250ms
/// debounce so rapid bursts of writes from an editor are coalesced
/// into a single reload. Listens for `.write`, `.extend`, `.delete`
/// and `.rename` so atomic-save replacements (which `unlink` the
/// original) still trigger a reload — AppDelegate will re-install
/// the watcher against the new inode when it next calls
/// `loadScript(from:)`.
///
/// The watcher holds the URL's security scope for its lifetime so
/// the file descriptor stays valid in the sandbox.
final class FileWatcher: @unchecked Sendable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SimpleTeleprompter",
        category: "FileWatcher"
    )

    private let url: URL
    private let fd: Int32
    private let didStartAccess: Bool
    private let source: DispatchSourceFileSystemObject
    private let debounceQueue = DispatchQueue(label: "FileWatcher.debounce")
    nonisolated(unsafe) private var debounceItem: DispatchWorkItem?

    private init(
        url: URL,
        fd: Int32,
        didStartAccess: Bool,
        source: DispatchSourceFileSystemObject
    ) {
        self.url = url
        self.fd = fd
        self.didStartAccess = didStartAccess
        self.source = source
    }

    /// Starts watching `url`. Returns `nil` if the file could not be
    /// opened with read access (sandbox denial, file missing, etc.).
    static func start(
        url: URL,
        onChange: @escaping @MainActor @Sendable () -> Void
    ) -> FileWatcher? {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
            Self.logger.warning("Could not open(O_EVTONLY) \(url.lastPathComponent, privacy: .public)")
            return nil
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )

        let watcher = FileWatcher(
            url: url,
            fd: fd,
            didStartAccess: didStartAccess,
            source: source
        )

        source.setEventHandler { [weak watcher] in
            watcher?.fileDidChange(onChange: onChange)
        }
        source.setCancelHandler { [fd] in
            close(fd)
        }
        source.activate()

        Self.logger.info("Watching \(url.lastPathComponent, privacy: .public)")
        return watcher
    }

    private func fileDidChange(onChange: @escaping @MainActor @Sendable () -> Void) {
        debounceItem?.cancel()
        let item = DispatchWorkItem {
            Task { @MainActor in
                onChange()
            }
        }
        debounceItem = item
        debounceQueue.asyncAfter(deadline: .now() + .milliseconds(250), execute: item)
    }

    nonisolated func stop() {
        debounceItem?.cancel()
        debounceItem = nil
        source.cancel()
        if didStartAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }

    deinit {
        debounceItem?.cancel()
        source.cancel()
        if didStartAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
