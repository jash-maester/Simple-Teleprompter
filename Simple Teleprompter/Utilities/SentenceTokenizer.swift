//
//  SentenceTokenizer.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import Foundation
import NaturalLanguage

/// Splits a body of text into sentences via `NLTokenizer(unit: .sentence)`
/// and counts the words in each via `NLTokenizer(unit: .word)`.
///
/// Pure value type with no instance state — safe to call from any actor.
struct SentenceTokenizer: Sendable {
    func tokenize(_ source: String) -> [Sentence] {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = trimmed
        var results: [Sentence] = []
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            let text = trimmed[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                results.append(Sentence(
                    id: UUID(),
                    text: text,
                    wordCount: Self.wordCount(in: text)
                ))
            }
            return true
        }
        return results
    }

    private static func wordCount(in text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }
}
