//
//  KeynoteController.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import AppKit
import Foundation
import OSLog

/// Sends "show next" / "show previous" Apple Events to Keynote so the
/// presentation advances in step with the teleprompter.
///
/// The controller dispatches AppleScript execution off the main queue
/// (NSAppleScript can block briefly while macOS validates entitlements
/// and routes the event) so the main actor stays responsive even if
/// Keynote takes a beat to respond.
///
/// Required for this to work:
/// - `com.apple.security.automation.apple-events` entitlement (in
///   `Simple Teleprompter.entitlements`).
/// - `NSAppleEventsUsageDescription` key in Info.plist (already set).
/// - User grants Automation permission the first time we send an event
///   to Keynote — macOS will prompt.
@MainActor
final class KeynoteController {
    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SimpleTeleprompter",
        category: "Keynote"
    )

    private nonisolated static let bundleId = "com.apple.iWork.Keynote"

    private let queue = DispatchQueue(label: "Keynote.AppleScript", qos: .userInitiated)

    /// `true` if Keynote is currently a running process. Safe to call
    /// off the main actor too — `NSWorkspace.runningApplications` is
    /// a nonisolated read.
    nonisolated func isRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == Self.bundleId }
    }

    func showNext() {
        run(source: #"tell application "Keynote" to if (count of documents) > 0 then tell document 1 to show next"#,
            label: "show next")
    }

    func showPrevious() {
        run(source: #"tell application "Keynote" to if (count of documents) > 0 then tell document 1 to show previous"#,
            label: "show previous")
    }

    func startSlideshow() {
        run(source: #"tell application "Keynote" to if (count of documents) > 0 then tell document 1 to start"#,
            label: "start slideshow")
    }

    func stopSlideshow() {
        run(source: #"tell application "Keynote" to if (count of documents) > 0 then stop"#,
            label: "stop slideshow")
    }

    private func run(source: String, label: String) {
        queue.async {
            guard let script = NSAppleScript(source: source) else {
                Self.logger.error("Could not compile AppleScript for \(label, privacy: .public)")
                return
            }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error {
                Self.logger.error("Keynote \(label, privacy: .public) failed: \(error, privacy: .public)")
            } else {
                Self.logger.info("Keynote \(label, privacy: .public) sent")
            }
        }
    }
}
