//
//  RootView.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Top-level SwiftUI view hosted inside the teleprompter panel.
///
/// Layers, back to front:
/// 1. ``WindowAccessor`` – invisible AppKit bridge publishing window state.
/// 2. ``GlassBackground`` – Liquid Glass (or black, when fullscreen) with tint.
/// 3. Script reader (``ScriptScrollView``) *or* the empty-state prompt.
/// 4. ``MouseTracker`` – invisible AppKit bridge for movement-driven pause.
/// 5. Drop-target highlight border, when relevant.
///
/// File loading routes through two paths:
/// 1. `.dropDestination` — file dragged from Finder.
/// 2. `.fileImporter` — opened from the empty-state button or ⌘O menu,
///    triggered by flipping `appEnv.pickerRequested` to `true`.
struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var isDropTargeted = false

    private static let mdType: UTType = UTType(filenameExtension: "md") ?? .plainText

    var body: some View {
        @Bindable var bindable = appEnv

        ZStack {
            WindowAccessor()
                .allowsHitTesting(false)
            GlassBackground()

            content
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ToolbarView()
                        .padding(.bottom, 12)
                        .padding(.horizontal, 16)
                }

            MouseTracker(environment: appEnv)
                .allowsHitTesting(false)

            if isDropTargeted {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(8)
                    .allowsHitTesting(false)
            }

            if appEnv.preRollActive {
                PreRollOverlay(countdown: appEnv.preRollCountdown) {
                    AppDelegate.shared?.cancelPreRoll()
                }
                .transition(.opacity)
            }
        }
        .onChange(of: appEnv.engine.currentSentenceIndex) { _, _ in
            AppDelegate.shared?.savePositionForCurrentScript()
        }
        .onChange(of: appEnv.engine.currentSlideIndex) { _, _ in
            AppDelegate.shared?.savePositionForCurrentScript()
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            AppDelegate.shared?.loadScript(from: url)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .fileImporter(
            isPresented: $bindable.pickerRequested,
            allowedContentTypes: [Self.mdType, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                AppDelegate.shared?.loadScript(from: url)
            case .failure:
                break
            }
        }
        .sheet(isPresented: $bindable.showSettings) {
            SettingsSheet()
                .environment(appEnv)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let script = appEnv.engine.script {
            ScriptScrollView(script: script)
                .contentShape(.rect)
                .onTapGesture {
                    AppDelegate.shared?.playPause()
                }
        } else {
            EmptyStatePrompt()
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
        }
    }
}

private struct EmptyStatePrompt: View {
    var body: some View {
        Button {
            AppDelegate.shared?.openScriptPicker()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48, weight: .light))
                Text("Open Script")
                    .font(.title2)
                Text("or drop a .md file here")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Text("⌘O")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }
}
