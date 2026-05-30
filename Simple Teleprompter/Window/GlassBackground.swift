//
//  GlassBackground.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import SwiftUI

/// Background layer for the teleprompter panel.
///
/// Renders macOS 26 Liquid Glass while windowed and swaps to opaque black
/// once ``AppEnvironment/isFullScreen`` flips, animating the cross-fade. A
/// tint rectangle painted with ``AppEnvironment/tintTheme``'s color at
/// ``AppEnvironment/tintOpacity`` sits over both backings so themes layer
/// uniformly on glass or black.
struct GlassBackground: View {
    @Environment(AppEnvironment.self) private var appEnv

    var body: some View {
        ZStack {
            if appEnv.isFullScreen {
                Rectangle()
                    .fill(.black)
            } else {
                GlassEffectContainer {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
            }

            Rectangle()
                .fill(appEnv.tintTheme.color.opacity(appEnv.tintOpacity))
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: appEnv.isFullScreen)
        .animation(.easeInOut(duration: 0.25), value: appEnv.tintTheme)
    }
}
