# Simple Teleprompter — Project Guide for Claude Code

A native macOS teleprompter utility with Liquid Glass UI. This file is loaded automatically by Claude Code; treat everything here as standing context for every session.

## Project metadata

- **Name**: Simple Teleprompter
- **Platform**: macOS 26+ (Tahoe and later; macOS 27 support planned)
- **Language**: Swift 6 (strict concurrency)
- **UI**: SwiftUI for content + AppKit (`NSPanel`, `NSWindowController`) for window control
- **Bundle identifier**: `in.ac.iitm.wsai.SimpleTeleprompter`
- **Distribution**: Direct (Developer ID), no sandbox
- **Author**: Jashaswimalya Acharjee (WSAI, IIT Madras)

## What this app does

A single-purpose tool: load a markdown file containing slides (`#` headings) and speech text, then scroll and highlight sentences at a controlled words-per-minute pace during a presentation. Floating, translucent Liquid Glass window in windowed mode; opaque black in fullscreen. Drives Keynote slide advancement via AppleScript ("driver mode"). Minimal UI, keyboard-shortcut-driven. Not an editor — never modifies the markdown file.

## Tech stack

- SwiftUI + AppKit interop
- `swift-markdown` ([apple/swift-markdown](https://github.com/swiftlang/swift-markdown)) for parsing
- `KeyboardShortcuts` ([sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)) for user-rebindable hotkeys
- `NaturalLanguage` framework for sentence tokenization
- `NSAppleScript` for Keynote control
- macOS 26 native `glassEffect()` / `GlassEffectContainer` APIs

## Directory layout

Swift source lives in the filesystem-synchronized folder `./Simple Teleprompter/`. Anything written inside that folder on disk is automatically part of the Xcode target — no `pbxproj` edits required.

```
Simple Teleprompter/                            ← Swift source root (Xcode target)
├── App/
│   ├── SimpleTeleprompterApp.swift             @main entry, AppDelegate
│   └── AppEnvironment.swift                    shared @Observable container
├── Window/
│   ├── TeleprompterWindowController.swift      NSWindowController + NSPanel setup
│   ├── WindowAccessor.swift                    SwiftUI → NSWindow bridge
│   └── GlassBackground.swift                   Liquid Glass + tint layer
├── Engine/
│   ├── ScriptModel.swift                       Script, Slide, Sentence types
│   ├── MarkdownParser.swift                    swift-markdown wrapper
│   ├── TeleprompterEngine.swift                playback state machine
│   └── TintTheme.swift                         tint enum + colors
├── Views/
│   ├── RootView.swift                          top-level SwiftUI view
│   ├── ScriptScrollView.swift                  scrolling text with highlight
│   ├── SlideView.swift                         one slide render
│   ├── ToolbarView.swift                       minimal bottom toolbar
│   ├── SettingsSheet.swift                     '?' dialog
│   └── PreRollOverlay.swift                    3-2-1 countdown
├── Services/
│   ├── ScriptLoader.swift                      file → Script
│   ├── KeynoteController.swift                 AppleScript bridge
│   ├── RecentFilesStore.swift                  UserDefaults-backed
│   ├── PositionStore.swift                     per-file resume
│   ├── FileWatcher.swift                       DispatchSource-based reload
│   └── MouseTracker.swift                      NSTrackingArea wrapper
├── Utilities/
│   └── SentenceTokenizer.swift                 NLTokenizer wrapper
└── Assets.xcassets
```

Documentation lives at the **project root**, outside the Swift source folder:

```
./CLAUDE.md   ← this file (Claude Code conventions)
./PLAN.md     ← phased work plan
./README.md   ← (optional, user-facing)
```

## Critical constraints

1. **Never edit `Simple Teleprompter.xcodeproj/project.pbxproj`.** All SPM dependencies, capabilities, and Info.plist keys are added through Xcode UI by the human. If you need a new dependency, capability, or Info.plist key, **stop and tell the human exactly what to add and where in Xcode**.
2. **Filesystem-synchronized folders.** Files placed inside `Simple Teleprompter/` on disk are auto-added to the Xcode target. Just write the files at the correct path.
3. **One phase at a time.** Work strictly within the requested phase from `PLAN.md`. Don't pre-implement future-phase features even if they seem obvious.
4. **Build verification is the human's job.** After each phase, the human builds in Xcode (`⌘B`) and reports errors back. Don't run `xcodebuild` unless asked.
5. **No tests for v1.** Skip writing unit tests unless the human explicitly requests them. Focus on shipping the app.
6. **Never modify the user's markdown scripts.** This app reads markdown; it never writes it.

## Code conventions

- **Swift 6 strict concurrency.** `@MainActor` on UI types and view models. Mark types `Sendable` where applicable.
- **`@Observable`, not `ObservableObject`.** Use the Swift 5.9+ Observation framework.
- **Value types for models.** Prefer `struct` and `enum` over `class` unless reference semantics are required.
- **Structured concurrency.** Use `async/await` and `Task` for asynchronous work. Use `DispatchQueue` / `DispatchSource` only where AppKit forces it.
- **No force unwraps in production code.** Use `guard let` / `if let`. Force-unwraps are acceptable only in unit tests.
- **No `print()` for logging.** Use `os.Logger` (`import OSLog`) with a per-subsystem logger.
- **One type per file.** Filename matches the type name.
- **Doc comments (`///`)** on public types and non-trivial methods.
- **No `// MARK:` clutter** in short files. Use them only when a file legitimately has multiple sections.

## Build & run

- Open `Simple Teleprompter.xcodeproj` in Xcode.
- `⌘R` to build and run.
- `⌘B` to build without running.
- `⌘⇧K` to clean build folder when things misbehave.
- Console output via `os.Logger` appears in Xcode's debug area (`⌘⇧Y`).

## Working-with-phases protocol

Each session, the human will say "do Phase N". Your workflow:

1. Read the relevant section of `PLAN.md`.
2. Execute exactly what that phase specifies — no more, no less.
3. Summarize at the end:
   - Files created or modified, with paths.
   - Anything the human needs to do in Xcode UI (add capability, add SPM package, set Info.plist key, etc.).
   - Anything you couldn't complete and why.

After the human confirms the phase builds in Xcode and meets the acceptance criteria, they'll commit and request the next phase.

## Reference snippets

**Liquid Glass background** (macOS 26+):
```swift
GlassEffectContainer {
    Rectangle()
        .fill(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
}
```

**Floating panel over fullscreen apps**:
```swift
window.level = .screenSaver
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
```

**Keynote AppleScript**:
```swift
let script = NSAppleScript(source: #"tell application "Keynote" to show next"#)
script?.executeAndReturnError(nil)
```
Keynote bundle id: `com.apple.iWork.Keynote`. Commands: `show next`, `show previous`, `start slideshow`, `stop slideshow`.
