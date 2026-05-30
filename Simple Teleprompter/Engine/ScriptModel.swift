//
//  ScriptModel.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import Foundation

/// A tokenized sentence within a slide. ``wordCount`` is pre-computed at
/// parse time so the engine can derive dwell duration without re-tokenizing.
struct Sentence: Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    let wordCount: Int
}

/// One slide of the script.
///
/// ``title`` is the H1 that started the slide. ``subheadings`` carries any
/// H2+ headings inside the slide so they can be rendered with their own
/// styling — they are *not* navigation boundaries; only H1 advances the
/// slide cursor. ``sentences`` is the slide body split via
/// ``SentenceTokenizer``.
struct Slide: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subheadings: [String]
    let sentences: [Sentence]
}

/// Parsed script. Order matches the source markdown exactly.
struct Script: Sendable {
    let slides: [Slide]
    let sourceURL: URL

    /// Flat traversal in document order. Computed on demand; cache the
    /// result if you iterate it more than a few times in a hot path.
    var flatSentences: [(slideIndex: Int, sentenceIndex: Int, sentence: Sentence)] {
        var out: [(slideIndex: Int, sentenceIndex: Int, sentence: Sentence)] = []
        for (s, slide) in slides.enumerated() {
            for (i, sentence) in slide.sentences.enumerated() {
                out.append((s, i, sentence))
            }
        }
        return out
    }
}
