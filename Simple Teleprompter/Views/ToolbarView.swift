//
//  ToolbarView.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import SwiftUI

/// Three independent Liquid Glass pills laid out across the bottom edge:
///
/// - **Left** — play / pause button.
/// - **Centre** — slide cursor as `N/M`.
/// - **Right** — WPM readout. Tapping opens ``SettingsSheet`` (same as `?`).
///
/// All three pills share auto-hide behaviour: while playback is running
/// they fade out after a couple of seconds of mouse inactivity, then
/// pop back in on any movement registered by ``MouseTracker``.
struct ToolbarView: View {
    @Environment(AppEnvironment.self) private var appEnv

    @State private var isVisible: Bool = true
    @State private var hideTask: Task<Void, Never>?

    private static let idleHideDelay: Duration = .seconds(2)
    private var engine: TeleprompterEngine { appEnv.engine }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 12) {
                playPausePill
                Spacer(minLength: 8)
                slideCountPill
                Spacer(minLength: 8)
                wpmPill
            }
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onChange(of: appEnv.mouseLastMoved) { _, _ in
            isVisible = true
            scheduleHideIfPlaying()
        }
        .onChange(of: engine.isPlaying) { _, playing in
            if !playing {
                isVisible = true
                hideTask?.cancel()
                hideTask = nil
            } else {
                scheduleHideIfPlaying()
            }
        }
    }

    private var playPausePill: some View {
        Button {
            AppDelegate.shared?.playPause()
        } label: {
            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .circle)
        .disabled(engine.script == nil)
    }

    private var slideCountPill: some View {
        Text(slideCounterText)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
    }

    private var wpmPill: some View {
        Button {
            appEnv.showSettings.toggle()
        } label: {
            HStack(spacing: 4) {
                Text("\(engine.wpm)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                Text("wpm")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .capsule)
        .help("Settings (?)")
    }

    private var slideCounterText: String {
        guard let script = engine.script, !script.slides.isEmpty else { return "—/—" }
        return "\(engine.currentSlideIndex + 1)/\(script.slides.count)"
    }

    private func scheduleHideIfPlaying() {
        hideTask?.cancel()
        guard engine.isPlaying else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: Self.idleHideDelay)
            if !Task.isCancelled, engine.isPlaying {
                isVisible = false
            }
        }
    }
}
