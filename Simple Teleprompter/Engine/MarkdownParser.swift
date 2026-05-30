//
//  MarkdownParser.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import Foundation
import Markdown
import OSLog

/// Walks a swift-markdown `Document` and emits ``Slide`` values.
///
/// Conventions:
/// - `H1` opens a new slide (and commits the previous one, if any).
/// - `H2` and deeper land in the current slide's ``Slide/subheadings`` for
///   visual rendering only — they do **not** subdivide playback.
/// - `Paragraph` text accumulates into the slide's body buffer.
/// - Anything else (lists, code, tables, …) is dropped with a warning, per
///   the v1 scope.
///
/// After each slide is committed, its accumulated body text is split into
/// ``Sentence`` values by ``SentenceTokenizer``.
struct MarkdownParser: Sendable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SimpleTeleprompter",
        category: "MarkdownParser"
    )

    private let tokenizer = SentenceTokenizer()

    func parse(_ source: String) -> [Slide] {
        let document = Document(parsing: source)
        var slides: [Slide] = []
        var currentTitle: String?
        var currentSubheadings: [String] = []
        var currentBuffer = ""

        func commitSlide() {
            guard let title = currentTitle else { return }
            slides.append(Slide(
                id: UUID(),
                title: title,
                subheadings: currentSubheadings,
                sentences: tokenizer.tokenize(currentBuffer)
            ))
        }

        for child in document.children {
            switch child {
            case let heading as Heading:
                if heading.level == 1 {
                    commitSlide()
                    currentTitle = Self.plainText(of: heading)
                    currentSubheadings = []
                    currentBuffer = ""
                } else {
                    if currentTitle == nil {
                        Self.logger.warning("H\(heading.level, privacy: .public) appears before first H1; ignoring.")
                    } else {
                        currentSubheadings.append(Self.plainText(of: heading))
                    }
                }
            case let paragraph as Paragraph:
                if currentTitle == nil {
                    Self.logger.warning("Paragraph appears before first H1; ignoring.")
                } else {
                    if !currentBuffer.isEmpty { currentBuffer += " " }
                    currentBuffer += Self.plainText(of: paragraph)
                }
            default:
                Self.logger.warning("Skipped top-level \(String(describing: type(of: child)), privacy: .public).")
            }
        }
        commitSlide()
        return slides
    }

    private static func plainText(of markup: any Markup) -> String {
        if let text = markup as? Text { return text.string }
        if markup is SoftBreak { return " " }
        if markup is LineBreak { return "\n" }
        if let code = markup as? InlineCode { return code.code }
        return markup.children.map { plainText(of: $0) }.joined()
    }
}
