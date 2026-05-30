//
//  ScriptLoader.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import Foundation
import OSLog

/// Loads a markdown file from disk and returns a parsed ``Script``.
///
/// `load(url:)` performs blocking I/O on the calling task's executor —
/// invoke from a non-main task so the main actor stays responsive while
/// the file is read and tokenized.
final class ScriptLoader: Sendable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SimpleTeleprompter",
        category: "ScriptLoader"
    )

    private let parser = MarkdownParser()

    func load(url: URL) async throws -> Script {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard let source = String(data: data, encoding: .utf8) else {
            throw ScriptLoaderError.invalidEncoding(url: url)
        }

        let slides = parser.parse(source)
        Self.logger.info("Loaded \(slides.count, privacy: .public) slide(s) from \(url.lastPathComponent, privacy: .public).")
        return Script(slides: slides, sourceURL: url)
    }
}

enum ScriptLoaderError: Error, CustomStringConvertible, Sendable {
    case invalidEncoding(url: URL)

    var description: String {
        switch self {
        case .invalidEncoding(let url):
            return "Could not decode \(url.lastPathComponent) as UTF-8 text."
        }
    }
}
