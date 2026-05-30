//
//  TeleprompterWindowController.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import AppKit
import OSLog
import SwiftUI

/// Manages the single floating `NSPanel` that hosts the teleprompter UI.
///
/// Phase 1 uses a regular (activating) panel at `.floating` level — clicks
/// inside the panel activate the app and the panel can become key, so SwiftUI
/// buttons and AppKit modals (`NSOpenPanel`) behave normally. Phase 2 will
/// switch to `.nonactivatingPanel` + `.screenSaver` level so the panel can
/// ride over a Keynote slideshow without stealing focus.
@MainActor
final class TeleprompterWindowController: NSWindowController {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SimpleTeleprompter",
        category: "WindowController"
    )

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment

        let contentRect = NSRect(x: 0, y: 0, width: 720, height: 480)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.titled, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
        // `.fullScreenPrimary` lets the panel itself enter native fullscreen.
        // Phase 8 (Keynote driver mode) will swap this to `.fullScreenAuxiliary`
        // so the panel can ride over Keynote's fullscreen slideshow instead.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.center()

        let hosting = NSHostingView(rootView: RootView().environment(environment))
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        super.init(window: panel)

        panel.setFrameAutosaveName("TeleprompterWindow")

        Self.logger.info("Teleprompter panel ready at \(NSStringFromRect(panel.frame), privacy: .public)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
