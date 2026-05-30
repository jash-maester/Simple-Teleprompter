//
//  PreRollOverlay.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import SwiftUI

/// Full-screen dimmed overlay with a centred Liquid-Glass disc that
/// counts down 3 → 2 → 1 → Go before the engine starts playing.
///
/// Shown only when ``AppEnvironment/preRollActive`` is true, which
/// `AppDelegate.playPause()` flips on if `AppEnvironment.preRollEnabled`
/// is set. A tap anywhere on the overlay cancels the countdown.
struct PreRollOverlay: View {
    let countdown: Int
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            GlassEffectContainer {
                Text(displayText)
                    .font(.system(size: 110, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 220, height: 220)
                    .glassEffect(.regular, in: .circle)
                    .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
                    .id(countdown)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.3), value: countdown)
    }

    private var displayText: String {
        countdown > 0 ? "\(countdown)" : "Go"
    }
}
