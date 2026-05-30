//
//  WindowAccessor.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import AppKit
import SwiftUI

/// SwiftUI bridge to the hosting `NSWindow`.
///
/// Inserts a transparent `NSView` into the SwiftUI hierarchy that calls a
/// hook when it first becomes part of a window. The hook hands the window
/// to ``Coordinator``, which subscribes to fullscreen and key-window
/// notifications and republishes their values to ``AppEnvironment`` so the
/// rest of the SwiftUI tree (notably ``GlassBackground``) can react.
struct WindowAccessor: NSViewRepresentable {
    @Environment(AppEnvironment.self) private var appEnv

    func makeNSView(context: Context) -> NSView {
        let view = WindowBridgeView()
        let coordinator = context.coordinator
        let env = appEnv
        view.onWindowChange = { window in
            guard let window else { return }
            coordinator.attach(to: window, env: env)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var observers: [NSObjectProtocol] = []
        private weak var attachedWindow: NSWindow?

        func attach(to window: NSWindow, env: AppEnvironment) {
            guard window !== attachedWindow else { return }
            detachAll()
            attachedWindow = window

            let center = NotificationCenter.default

            observers.append(center.addObserver(
                forName: NSWindow.didEnterFullScreenNotification,
                object: window,
                queue: .main
            ) { _ in
                Task { @MainActor in env.isFullScreen = true }
            })

            observers.append(center.addObserver(
                forName: NSWindow.didExitFullScreenNotification,
                object: window,
                queue: .main
            ) { _ in
                Task { @MainActor in env.isFullScreen = false }
            })

            // Intentionally NO `didResignKey` observer. The user often
            // switches focus to Keynote / Preview / PowerPoint while the
            // teleprompter is running — that's the driver-mode workflow,
            // not a reason to pause.

            env.isFullScreen = window.styleMask.contains(.fullScreen)
        }

        func detachAll() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
        }
    }
}

/// Plain `NSView` that fires a hook whenever it joins or leaves a window.
/// Used by ``WindowAccessor`` to learn the hosting `NSWindow` reference
/// without polling.
private final class WindowBridgeView: NSView {
    var onWindowChange: (@MainActor (NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
