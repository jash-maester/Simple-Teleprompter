//
//  TeleprompterEngine.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import Foundation
import Observation
import OSLog

/// Playback state machine for the teleprompter.
///
/// Owns the loaded ``Script`` and the cursor (`currentSlideIndex` /
/// `currentSentenceIndex`). When playing, advances the sentence cursor on
/// a per-sentence dwell timer derived from each sentence's word count and
/// the current ``wpm``. Manual navigation methods (next/previous slide or
/// sentence) move the cursor without touching ``isPlaying``.
@Observable
@MainActor
final class TeleprompterEngine {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SimpleTeleprompter",
        category: "Engine"
    )

    /// Why the engine is currently paused (if it is).
    ///
    /// The scroll-event monitor uses this to decide whether to auto-resume
    /// after the user stops scrolling: only `.userScroll` pauses are
    /// eligible. Explicit `.user` pauses stay paused until the user plays
    /// again.
    enum PauseReason: Sendable {
        case user
        case userScroll
    }

    private static let wpmKey = "settings.wpm"

    var isPlaying: Bool = false
    var isPaused: Bool = false
    var wpm: Int = 140 {
        didSet { UserDefaults.standard.set(wpm, forKey: Self.wpmKey) }
    }
    var currentSlideIndex: Int = 0
    var currentSentenceIndex: Int = 0
    var script: Script?

    @ObservationIgnored
    var pauseReason: PauseReason?

    @ObservationIgnored
    private var playbackTask: Task<Void, Never>?

    init() {
        if UserDefaults.standard.object(forKey: Self.wpmKey) != nil {
            wpm = UserDefaults.standard.integer(forKey: Self.wpmKey)
        }
    }

    /// Replaces the active script. Cancels any running playback and resets
    /// the cursor to the beginning.
    func setScript(_ script: Script?) {
        stop()
        self.script = script
        currentSlideIndex = 0
        currentSentenceIndex = 0
        Self.logger.info("Engine loaded script with \(script?.slides.count ?? 0, privacy: .public) slide(s).")
    }

    /// Starts (or resumes) automatic sentence advancement.
    func play() {
        guard currentSentence != nil else {
            Self.logger.notice("play() ignored — no current sentence.")
            return
        }
        playbackTask?.cancel()
        isPlaying = true
        isPaused = false
        pauseReason = nil
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, let sentence = self.currentSentence {
                let dwell = self.dwellTime(for: sentence)
                try? await Task.sleep(for: .seconds(dwell))
                if Task.isCancelled { break }
                if !self.advanceForPlayback() { break }
            }
            // If we exited via cancellation, the canceller already set isPlaying.
            if !Task.isCancelled {
                self.isPlaying = false
                self.playbackTask = nil
            }
        }
        playbackTask = task
    }

    /// Pauses playback, preserving the cursor.
    ///
    /// Callers should pass a ``PauseReason`` so consumers (e.g.
    /// `MouseTracker`'s auto-resume logic) can tell apart automatic pauses
    /// from explicit user pauses.
    func pause(reason: PauseReason = .user) {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        isPaused = true
        pauseReason = reason
    }

    func togglePlayPause() {
        if isPlaying { pause(reason: .user) } else { play() }
    }

    /// Stops playback and rewinds to the start of the current slide.
    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        isPaused = false
        pauseReason = nil
        currentSentenceIndex = 0
    }

    func nextSlide() {
        guard let script else { return }
        guard currentSlideIndex + 1 < script.slides.count else { return }
        currentSlideIndex += 1
        currentSentenceIndex = 0
    }

    func previousSlide() {
        guard currentSlideIndex > 0 else { return }
        currentSlideIndex -= 1
        currentSentenceIndex = 0
    }

    func restartCurrentSlide() {
        currentSentenceIndex = 0
    }

    /// Jumps the cursor to an arbitrary `(slide, sentence)` position.
    /// Used by the click-/tap-to-seek interaction on each rendered
    /// sentence. Out-of-range coordinates are silently ignored.
    func seek(toSlide slideIndex: Int, sentenceIndex: Int) {
        guard let script else { return }
        guard slideIndex >= 0, slideIndex < script.slides.count else { return }
        let slide = script.slides[slideIndex]
        guard sentenceIndex >= 0, sentenceIndex < slide.sentences.count else { return }

        currentSlideIndex = slideIndex
        currentSentenceIndex = sentenceIndex
    }

    func nextSentence() {
        _ = advanceForPlayback()
    }

    func previousSentence() {
        if currentSentenceIndex > 0 {
            currentSentenceIndex -= 1
        } else if currentSlideIndex > 0 {
            currentSlideIndex -= 1
            let prev = script?.slides[currentSlideIndex]
            currentSentenceIndex = max(0, (prev?.sentences.count ?? 1) - 1)
        }
    }

    /// The sentence the cursor currently points at, if any.
    var currentSentence: Sentence? {
        guard let script,
              script.slides.indices.contains(currentSlideIndex) else { return nil }
        let slide = script.slides[currentSlideIndex]
        guard slide.sentences.indices.contains(currentSentenceIndex) else { return nil }
        return slide.sentences[currentSentenceIndex]
    }

    /// Steps the cursor forward by one sentence, crossing slide boundaries
    /// as needed. Returns `false` if the cursor is already at the last
    /// sentence of the last slide.
    @discardableResult
    private func advanceForPlayback() -> Bool {
        guard let script else { return false }
        guard script.slides.indices.contains(currentSlideIndex) else { return false }
        let slide = script.slides[currentSlideIndex]
        if currentSentenceIndex + 1 < slide.sentences.count {
            currentSentenceIndex += 1
            return true
        }
        if currentSlideIndex + 1 < script.slides.count {
            currentSlideIndex += 1
            currentSentenceIndex = 0
            return true
        }
        return false
    }

    private func dwellTime(for sentence: Sentence) -> Double {
        guard wpm > 0 else { return 1.5 }
        return max(1.5, Double(sentence.wordCount) / Double(wpm) * 60.0)
    }
}
