//
//  ScriptScrollView.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import SwiftUI

/// Auto-scrolling reader view.
///
/// A `ScrollViewReader` wraps a vertically-scrolling `VStack` of
/// ``SlideView`` instances. Whenever the engine's cursor moves the
/// current sentence is scrolled back to the centre of the visible
/// region with a brief easing curve.
///
/// We deliberately use a **non-lazy** `VStack` rather than `LazyVStack`.
/// Lazy layout means views past the visible region aren't constructed
/// until the scroll approaches them — and `ScrollViewProxy.scrollTo`
/// over a long distance ends up stitching new views into place mid-
/// animation, producing the "jumping from back" effect. For the size
/// of scripts this app handles (kilobytes of markdown, low hundreds of
/// sentences), eager layout is cheap and lets `scrollTo` land precisely.
struct ScriptScrollView: View {
    let script: Script

    @Environment(AppEnvironment.self) private var appEnv

    private var engine: TeleprompterEngine { appEnv.engine }

    private static let scrollAnimation: Animation = .easeInOut(duration: 0.35)

    var body: some View {
        let starts = slideStartFlatIndices
        let currentFlat = currentFlatIndex(starts: starts)

        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: appEnv.lineSpacing * 2) {
                        ForEach(Array(script.slides.enumerated()), id: \.element.id) { index, slide in
                            SlideView(
                                slide: slide,
                                slideIndex: index,
                                slideStartFlatIndex: starts[index],
                                currentFlatIndex: currentFlat
                            )
                        }
                        Spacer(minLength: geo.size.height * 0.6)
                    }
                    .padding(.horizontal, geo.size.width * 0.17)
                    .padding(.top, geo.size.height * 0.4)
                }
                .scaleEffect(x: appEnv.isMirrored ? -1 : 1, y: 1)
                // Single observer — fires once per cursor move regardless
                // of whether it was a sentence step or a slide hop.
                .onChange(of: currentFlat) { _, _ in
                    scrollToCurrent(proxy: proxy)
                }
                // Re-centre on play/resume even if the cursor didn't
                // change. The brief delay lets any pending user-scroll
                // inertia settle before we issue the programmatic scroll.
                .onChange(of: engine.isPlaying) { _, isPlaying in
                    guard isPlaying else { return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(120))
                        scrollToCurrent(proxy: proxy)
                    }
                }
                .onAppear {
                    scrollToCurrent(proxy: proxy, animated: false)
                }
            }
        }
    }

    private var slideStartFlatIndices: [Int] {
        var result: [Int] = []
        result.reserveCapacity(script.slides.count)
        var running = 0
        for slide in script.slides {
            result.append(running)
            running += slide.sentences.count
        }
        return result
    }

    private func currentFlatIndex(starts: [Int]) -> Int {
        let slideIdx = engine.currentSlideIndex
        guard starts.indices.contains(slideIdx) else { return 0 }
        return starts[slideIdx] + engine.currentSentenceIndex
    }

    private func scrollToCurrent(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let sentenceID = currentSentenceID() else { return }
        if animated {
            withAnimation(Self.scrollAnimation) {
                proxy.scrollTo(sentenceID, anchor: .center)
            }
        } else {
            proxy.scrollTo(sentenceID, anchor: .center)
        }
    }

    private func currentSentenceID() -> UUID? {
        let slideIndex = engine.currentSlideIndex
        guard slideIndex >= 0, slideIndex < script.slides.count else { return nil }
        let slide = script.slides[slideIndex]
        let sentenceIndex = engine.currentSentenceIndex
        guard sentenceIndex >= 0, sentenceIndex < slide.sentences.count else { return nil }
        return slide.sentences[sentenceIndex].id
    }
}
