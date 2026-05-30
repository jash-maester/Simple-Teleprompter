//
//  MouseTracker.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import AppKit
import SwiftUI

/// SwiftUI bridge that installs an `NSTrackingArea` on its hosting view
/// and updates ``AppEnvironment/mouseLastMoved`` on every movement.
///
/// Mouse movement no longer affects playback (the user often passes the
/// pointer over the panel while presenting). Playback-pause-on-scroll is
/// owned by ``AppDelegate``'s scroll-event monitor.
struct MouseTracker: NSViewRepresentable {
    let environment: AppEnvironment

    func makeNSView(context: Context) -> NSView {
        let view = MouseTrackerView()
        view.environment = environment
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MouseTrackerView)?.environment = environment
    }
}

@MainActor
private final class MouseTrackerView: NSView {
    weak var environment: AppEnvironment?

    override var acceptsFirstResponder: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        environment?.mouseLastMoved = Date()
    }
}
