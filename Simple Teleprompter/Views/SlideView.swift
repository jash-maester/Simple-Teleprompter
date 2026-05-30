//
//  SlideView.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import SwiftUI

/// Renders a single slide: H1 title, any H2+ subheadings, then the body
/// sentences as individual `Text` views so each can be scrolled-to and
/// highlighted independently by the engine.
///
/// Sentences fade with their distance from the **current** sentence —
/// the centre line is fully opaque, neighbours dim gently, and far-away
/// lines settle at a floor so they remain readable peripherally.
struct SlideView: View {
    let slide: Slide
    let slideIndex: Int
    let slideStartFlatIndex: Int
    let currentFlatIndex: Int

    @Environment(AppEnvironment.self) private var appEnv

    private var fontSize: Double { appEnv.fontSize }
    private var lineSpacing: Double { appEnv.lineSpacing }

    private static let fadeAnimation: Animation = .easeInOut(duration: 0.35)

    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            Text(slide.title)
                .font(.system(size: fontSize * 1.6, weight: .bold, design: .serif))
                .opacity(opacity(forFlat: slideStartFlatIndex))
                .animation(Self.fadeAnimation, value: currentFlatIndex)

            ForEach(slide.subheadings, id: \.self) { sub in
                Text(sub)
                    .font(.system(size: fontSize * 1.2, weight: .semibold, design: .serif))
                    .foregroundStyle(.secondary)
                    .opacity(opacity(forFlat: slideStartFlatIndex))
                    .animation(Self.fadeAnimation, value: currentFlatIndex)
            }

            ForEach(Array(slide.sentences.enumerated()), id: \.element.id) { index, sentence in
                let flat = slideStartFlatIndex + index
                Text(sentence.text)
                    .font(.system(size: fontSize, weight: .medium, design: .serif))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(highlightBackground(isCurrent: flat == currentFlatIndex))
                    .opacity(opacity(forFlat: flat))
                    .id(sentence.id)
                    .animation(Self.fadeAnimation, value: currentFlatIndex)
                    .contentShape(.rect)
                    .onTapGesture {
                        appEnv.engine.seek(toSlide: slideIndex, sentenceIndex: index)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func opacity(forFlat flat: Int) -> Double {
        let distance = abs(flat - currentFlatIndex)
        if distance == 0 { return 1.0 }
        return max(appEnv.peripheralOpacity, 1.0 - Double(distance) * appEnv.opacityDropOff)
    }

    @ViewBuilder
    private func highlightBackground(isCurrent: Bool) -> some View {
        if isCurrent {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.18))
        } else {
            Color.clear
        }
    }
}
