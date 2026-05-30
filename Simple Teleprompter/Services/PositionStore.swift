//
//  PositionStore.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import Foundation
import OSLog

/// Per-file cursor persistence — remembers where the user was in a
/// script so reopening the file resumes at the same sentence.
///
/// Keyed by `url.absoluteString` (security-scoped bookmarks resolve to
/// the same absolute path, so the key is stable across launches even
/// in a sandboxed app). Stored as JSON in `UserDefaults` under the key
/// `Positions`.
@MainActor
final class PositionStore {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SimpleTeleprompter",
        category: "PositionStore"
    )

    private static let defaultsKey = "Positions"

    private struct Position: Codable {
        let slideIndex: Int
        let sentenceIndex: Int
    }

    func save(slideIndex: Int, sentenceIndex: Int, for url: URL) {
        guard slideIndex >= 0, sentenceIndex >= 0 else { return }
        var dict = loadDict()
        let payload = Position(slideIndex: slideIndex, sentenceIndex: sentenceIndex)
        guard let data = try? JSONEncoder().encode(payload) else {
            Self.logger.warning("Could not encode position for \(url.lastPathComponent, privacy: .public)")
            return
        }
        dict[url.absoluteString] = data
        UserDefaults.standard.set(dict, forKey: Self.defaultsKey)
    }

    func load(for url: URL) -> (slideIndex: Int, sentenceIndex: Int)? {
        let dict = loadDict()
        guard let data = dict[url.absoluteString],
              let payload = try? JSONDecoder().decode(Position.self, from: data) else { return nil }
        return (payload.slideIndex, payload.sentenceIndex)
    }

    func forget(_ url: URL) {
        var dict = loadDict()
        dict.removeValue(forKey: url.absoluteString)
        UserDefaults.standard.set(dict, forKey: Self.defaultsKey)
    }

    private func loadDict() -> [String: Data] {
        UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: Data] ?? [:]
    }
}
