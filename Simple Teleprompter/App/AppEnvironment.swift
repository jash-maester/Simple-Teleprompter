//
//  AppEnvironment.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import Foundation
import Observation
import SwiftUI

/// Shared, main-actor-isolated container for app-wide observable state.
///
/// Stored properties marked as **persistent** in the property comment
/// write through to `UserDefaults` on every change via `didSet`, and are
/// re-read in `init()` so the user's settings survive across launches.
/// Ephemeral runtime flags (fullscreen state, pickerRequested, pre-roll
/// countdown, mouse-move timestamp…) intentionally don't persist.
@Observable
@MainActor
final class AppEnvironment {
    // MARK: Persistent settings

    var tintOpacity: Double = 0.35 {
        didSet { UserDefaults.standard.set(tintOpacity, forKey: Keys.tintOpacity) }
    }

    var tintTheme: TintTheme = .charcoal {
        didSet { UserDefaults.standard.set(tintTheme.rawValue, forKey: Keys.tintTheme) }
    }

    var fontSize: Double = 32 {
        didSet { UserDefaults.standard.set(fontSize, forKey: Keys.fontSize) }
    }

    var isMirrored: Bool = false {
        didSet { UserDefaults.standard.set(isMirrored, forKey: Keys.isMirrored) }
    }

    var lineSpacing: Double = 12 {
        didSet { UserDefaults.standard.set(lineSpacing, forKey: Keys.lineSpacing) }
    }

    /// Floor for sentences far from the cursor.
    var peripheralOpacity: Double = 0.3 {
        didSet { UserDefaults.standard.set(peripheralOpacity, forKey: Keys.peripheralOpacity) }
    }

    /// How much opacity drops per sentence of distance from the cursor.
    var opacityDropOff: Double = 0.14 {
        didSet { UserDefaults.standard.set(opacityDropOff, forKey: Keys.opacityDropOff) }
    }

    /// Pre-roll countdown before playback.
    var preRollEnabled: Bool = false {
        didSet { UserDefaults.standard.set(preRollEnabled, forKey: Keys.preRollEnabled) }
    }

    /// Restore the cursor position when reopening a known file.
    var resumeEnabled: Bool = true {
        didSet { UserDefaults.standard.set(resumeEnabled, forKey: Keys.resumeEnabled) }
    }

    /// Auto-resume playback ~2s after the user stops scrolling.
    var autoResumeAfterScroll: Bool = true {
        didSet { UserDefaults.standard.set(autoResumeAfterScroll, forKey: Keys.autoResumeAfterScroll) }
    }

    // MARK: Ephemeral runtime state (intentionally not persisted)

    var isFullScreen: Bool = false

    /// Set to `true` to ask ``RootView`` to present its `.fileImporter`.
    var pickerRequested: Bool = false

    /// Toggled by `?` / ⌘, to show ``SettingsSheet``.
    var showSettings: Bool = false

    /// Updated by ``MouseTracker`` on every movement.
    var mouseLastMoved: Date = .distantPast

    /// True while the pre-roll countdown overlay is visible.
    var preRollActive: Bool = false

    /// Current countdown digit shown by ``PreRollOverlay``.
    var preRollCountdown: Int = 3

    // MARK: Owned services

    let engine = TeleprompterEngine()
    let recentStore = RecentFilesStore()
    let positionStore = PositionStore()

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: Keys.tintOpacity) != nil { tintOpacity = d.double(forKey: Keys.tintOpacity) }
        if let raw = d.string(forKey: Keys.tintTheme), let t = TintTheme(rawValue: raw) { tintTheme = t }
        if d.object(forKey: Keys.fontSize) != nil { fontSize = d.double(forKey: Keys.fontSize) }
        if d.object(forKey: Keys.isMirrored) != nil { isMirrored = d.bool(forKey: Keys.isMirrored) }
        if d.object(forKey: Keys.lineSpacing) != nil { lineSpacing = d.double(forKey: Keys.lineSpacing) }
        if d.object(forKey: Keys.peripheralOpacity) != nil { peripheralOpacity = d.double(forKey: Keys.peripheralOpacity) }
        if d.object(forKey: Keys.opacityDropOff) != nil { opacityDropOff = d.double(forKey: Keys.opacityDropOff) }
        if d.object(forKey: Keys.preRollEnabled) != nil { preRollEnabled = d.bool(forKey: Keys.preRollEnabled) }
        if d.object(forKey: Keys.resumeEnabled) != nil { resumeEnabled = d.bool(forKey: Keys.resumeEnabled) }
        if d.object(forKey: Keys.autoResumeAfterScroll) != nil { autoResumeAfterScroll = d.bool(forKey: Keys.autoResumeAfterScroll) }
    }

    private enum Keys {
        static let tintOpacity = "settings.tintOpacity"
        static let tintTheme = "settings.tintTheme"
        static let fontSize = "settings.fontSize"
        static let isMirrored = "settings.isMirrored"
        static let lineSpacing = "settings.lineSpacing"
        static let peripheralOpacity = "settings.peripheralOpacity"
        static let opacityDropOff = "settings.opacityDropOff"
        static let preRollEnabled = "settings.preRollEnabled"
        static let resumeEnabled = "settings.resumeEnabled"
        static let autoResumeAfterScroll = "settings.autoResumeAfterScroll"
    }
}
