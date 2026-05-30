# Simple Teleprompter — Phased Work Plan

Work strictly one phase at a time. Each phase is self-contained: it builds on the previous one and produces a runnable app. After each phase, the human builds in Xcode (⌘B), verifies acceptance criteria, commits, and requests the next phase.

All file paths below are relative to the Swift source root `Simple Teleprompter/`.

---

## Phase 1 — Foundation & project layout

**Goal**: Create the folder structure, app scaffold, and shared state container. After this phase the app builds and shows an empty translucent panel.

**Files to create**:

```
App/
  SimpleTeleprompterApp.swift     (move + rename existing Simple_TeleprompterApp.swift here)
  AppEnvironment.swift
Window/
  TeleprompterWindowController.swift
  WindowAccessor.swift
Views/
  RootView.swift
Engine/                            (created empty, populated in later phases)
Services/                          (created empty)
Utilities/                         (created empty)
```

**Tasks**:

- Delete the auto-generated `ContentView.swift`.
- `SimpleTeleprompterApp.swift` uses `NSApplicationDelegateAdaptor`. The `App` body returns `Settings { EmptyView() }` so no default window scene exists — we create the window manually via the controller for full control.
- `AppEnvironment` is an `@Observable @MainActor final class` shell. Phase 1 adds no properties yet; later phases will.
- `TeleprompterWindowController` subclasses `NSWindowController`, creates an `NSPanel` (not `NSWindow`) with:
  - `styleMask = [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView]`
  - `isOpaque = false`
  - `backgroundColor = .clear`
  - `titlebarAppearsTransparent = true`
  - `titleVisibility = .hidden`
  - `level = .floating` (will bump to `.screenSaver` in Phase 2)
  - Hosts `RootView` via `NSHostingView`.
- `RootView` for now renders `Text("Simple Teleprompter").padding()` over `Color.clear`.
- `AppDelegate` (defined inside `SimpleTeleprompterApp.swift`) instantiates and shows the window controller in `applicationDidFinishLaunching`.

**Acceptance**: `⌘R` shows a small floating panel with transparent edges displaying "Simple Teleprompter".

---

## Phase 2 — Window infrastructure: glass, levels, fullscreen

**Goal**: The panel sits above all other windows including fullscreen apps. Liquid Glass background in windowed mode, opaque black in fullscreen, with a global tint opacity.

**Files**:

- Extend `Window/TeleprompterWindowController.swift`:
  - `level = .screenSaver`
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`
  - `hidesOnDeactivate = false`
  - Default size 720×480, centered on screen, frame autosaved via `setFrameAutosaveName("TeleprompterWindow")`.
- Create `Window/GlassBackground.swift`: SwiftUI view using `GlassEffectContainer` + `.glassEffect()` for the background. A `Color` tint overlay reads opacity from `AppEnvironment.tintOpacity` and color from `AppEnvironment.tintColor`. When `isFullScreen` is true, swap glass for `Color.black` via `withAnimation`.
- `Window/WindowAccessor.swift`: an `NSViewRepresentable` that bridges to `NSWindow`. Observes `NSWindow.didEnterFullScreenNotification` / `didExitFullScreenNotification` and publishes to `AppEnvironment.isFullScreen`. Observes `didResignKeyNotification` / `didBecomeKeyNotification` and publishes to `AppEnvironment.hasFocus`.
- Add to `AppEnvironment`:
  - `var tintOpacity: Double = 0.35`
  - `var tintColor: Color = .black`
  - `var isFullScreen: Bool = false`
  - `var hasFocus: Bool = true`
- Add keyboard shortcut `⌘⌃F` (Cmd-Control-F) to toggle fullscreen via `window?.toggleFullScreen(nil)`.

**Acceptance**: Panel renders Liquid Glass. `⌘⌃F` enters fullscreen with black background; exiting restores glass. Panel stays visible when Keynote (or any other app) enters fullscreen.

---

## Phase 3 — Markdown parsing & model

**Goal**: Load a `.md` file, parse it into a `Script` with slides and sentences. No playback yet — just render static content.

**Files**:

- `Engine/ScriptModel.swift`:
  - `struct Sentence: Identifiable, Hashable { let id: UUID; let text: String; let wordCount: Int }`
  - `struct Slide: Identifiable, Hashable { let id: UUID; let title: String; let subheadings: [String]; let sentences: [Sentence] }` — `H1` defines slide boundaries; `H2`/`H3`/etc. are stored in `subheadings` for visual rendering within the slide, **not** as separate navigation boundaries.
  - `struct Script { let slides: [Slide]; let sourceURL: URL }` with a computed `flatSentences: [(slideIndex: Int, sentenceIndex: Int, sentence: Sentence)]`.
- `Engine/MarkdownParser.swift`: uses `import Markdown`. Walks the `Document` tree:
  - `Heading` with `level == 1` → starts a new `Slide` (commits the previous one if any).
  - `Heading` with `level >= 2` → appended to current slide's `subheadings` as plain text.
  - `Paragraph` → text appended to current slide's body buffer.
  - Other block types (lists, tables, code, etc.) → ignored for v1; emit a `Logger.warning` so we can see them in the console.
  - After parsing, each slide's body buffer is split into sentences via `SentenceTokenizer`.
- `Utilities/SentenceTokenizer.swift`: wraps `NLTokenizer(unit: .sentence)`. Returns `[Sentence]` with `wordCount` computed via `NLTokenizer(unit: .word)` on each sentence.
- `Services/ScriptLoader.swift`: `final class ScriptLoader { func load(url: URL) async throws -> Script }`.
- Update `RootView`:
  - Add a state binding for the current `Script?`.
  - On `.fileImporter` (triggered by `⌘O`), call `ScriptLoader.load`.
  - If a script is loaded, render the first slide's title + sentences as plain SwiftUI `Text` (no highlight, no scroll yet).
  - If no script, show a centered "Open a script (⌘O)" prompt.
- Add to `AppEnvironment`: `var script: Script?` and `var currentSlideIndex: Int = 0`.
- Wire `⌘O` keyboard shortcut to trigger the file importer.

**Acceptance**: `⌘O` opens a file picker. Loading a `test.md` with two `#` slides each containing 3-4 sentences renders the first slide's content as plain text inside the panel.

---

## Phase 4 — Teleprompter engine

**Goal**: Playback state machine. WPM-driven sentence advancement. Manual navigation. No rendering changes yet.

**Files**:

- `Engine/TeleprompterEngine.swift`: `@Observable @MainActor final class TeleprompterEngine`.
  - Properties:
    - `var isPlaying: Bool = false`
    - `var isPaused: Bool = false` (paused = was playing, manually interrupted; distinct from `!isPlaying` which is stopped)
    - `var wpm: Int = 140`
    - `var currentSlideIndex: Int = 0`
    - `var currentSentenceIndex: Int = 0`
    - `var script: Script?`
  - Methods: `play()`, `pause()`, `togglePlayPause()`, `stop()`, `nextSlide()`, `previousSlide()`, `restartCurrentSlide()`, `nextSentence()`, `previousSentence()`.
  - Private: a `Task<Void, Never>?` playback task. `play()` cancels any existing task, creates a new one that loops:
    ```swift
    while !Task.isCancelled, let s = currentSentence {
        try? await Task.sleep(for: .seconds(dwellTime(for: s)))
        if Task.isCancelled { break }
        advance()
    }
    ```
  - `dwellTime(for sentence: Sentence) -> Double` = `max(1.5, Double(sentence.wordCount) / Double(wpm) * 60.0)`.
  - `pause()` cancels the task but preserves indices. `stop()` cancels and resets `currentSentenceIndex` to 0 of current slide.
- Move `currentSlideIndex` from `AppEnvironment` into the engine. `AppEnvironment` now owns the engine: `let engine = TeleprompterEngine()`.
- Add temporary debug buttons to `RootView`: Play, Pause, Next Slide, Prev Slide. Display `currentSlideIndex / currentSentenceIndex` as text.

**Acceptance**: Pressing Play advances `currentSentenceIndex` automatically at 140 WPM (verifiable visually). Pause halts. Next/Prev navigate slides.

---

## Phase 5 — Rendering: scroll view, sentence highlight, mirror, font size

**Goal**: Beautiful readable rendering with smooth auto-scroll keeping the current sentence centered and softly highlighted. Mirror mode and adjustable font size.

**Files**:

- `Views/ScriptScrollView.swift`:
  - `ScrollViewReader` wrapping a `ScrollView` containing a `LazyVStack` of `SlideView` instances.
  - On change of `engine.currentSentenceIndex`, scroll to the current sentence's anchor with `withAnimation(.easeInOut(duration: 0.4))`. Use sentence `id` as the scroll anchor.
  - Generous horizontal padding (15-20% of window width).
- `Views/SlideView.swift`: renders one slide. Title in large bold; subheadings (if any) in medium weight; sentences rendered as individual `Text` views inside a `VStack` so each can be scrolled to independently. The current sentence (matched by ID against `engine.currentSentenceIndex` for the current slide) gets a `.background(RoundedRectangle(cornerRadius: 6).fill(.tint.opacity(0.18)))` with `.animation(.easeInOut(duration: 0.25), value: engine.currentSentenceIndex)`.
- Add to `AppEnvironment`:
  - `var fontSize: Double = 32`
  - `var isMirrored: Bool = false`
  - `var lineSpacing: Double = 12`
- Apply `.scaleEffect(x: appEnv.isMirrored ? -1 : 1, y: 1)` to the scroll view's content for mirror mode.
- Body font: `.system(size: fontSize, weight: .medium, design: .serif)`. Titles: `.system(size: fontSize * 1.6, weight: .bold, design: .serif)`. Subheadings: `.system(size: fontSize * 1.2, weight: .semibold, design: .serif)`.
- Remove the debug buttons from Phase 4 — playback is now driven by the real engine and visible via highlight.

**Acceptance**: Loading a script displays it with title + body sentences. Pressing Play (still via Phase-6 keyboard shortcut soon — for now keep a single hidden debug toggle) smoothly scrolls and highlights each sentence. Toggling mirror flips the text.

---

## Phase 6 — Controls: toolbar, settings sheet, keyboard, mouse, focus

**Goal**: Minimal toolbar, `?`-triggered settings sheet, all keyboard shortcuts, mouse-and-focus pause behavior.

**Files**:

- `Views/ToolbarView.swift`: a slim glass-backed bar at the bottom of the window showing play/pause icon button, `slide N / M` text, current WPM. Hides itself with a fade-out after ~2 seconds of mouse inactivity while playing; reappears on mouse movement inside the window.
- `Views/SettingsSheet.swift`: opened by pressing `?`. Sliders/steppers for WPM (60-260), font size (16-72), tint opacity (0-1), line spacing (0-40). Toggles for mirror mode, pre-roll countdown, Keynote sync. Picker for tint theme (Phase 7 will populate the cases). Closes on `Esc` or `?` again.
- `Services/MouseTracker.swift`: an `NSViewRepresentable` that installs an `NSTrackingArea` with `[.activeAlways, .mouseMoved, .inVisibleRect]`. Accumulates movement; if movement exceeds 10pt within a 150ms window while `engine.isPlaying`, calls `engine.pause()`.
- Wire `WindowAccessor` to call `engine.pause()` when `windowDidResignKey` fires.
- A single click anywhere on the script area calls `engine.togglePlayPause()`.

**Keyboard shortcuts** (use SwiftUI `.keyboardShortcut` where possible; fall back to a single `NSEvent.addLocalMonitorForEvents` block for keys SwiftUI can't handle cleanly, e.g. plain arrows without modifiers):

| Key | Action |
|---|---|
| `Space` | Toggle play/pause |
| `→` | Next slide |
| `←` | Previous slide |
| `⇧→` | Next sentence (manual override) |
| `⇧←` | Previous sentence |
| `↑` | Restart current slide |
| `?` | Toggle settings sheet |
| `⌘+` / `⌘=` | Increase font size |
| `⌘-` | Decrease font size |
| `M` | Toggle mirror |
| `⌘⌃F` | Toggle fullscreen |
| `⌘O` | Open file |
| `Esc` | Exit fullscreen if in it; otherwise stop playback |

**Acceptance**: All shortcuts work. Trackpad movement during playback pauses. Cmd-Tabbing away pauses. `?` toggles the settings sheet with live-updating controls.

---

## Phase 7 — Themed glass tints + recent files menu

**Goal**: User picks a tint theme; recent files menu in the File menu.

**Files**:

- `Engine/TintTheme.swift`:
  ```swift
  enum TintTheme: String, CaseIterable, Codable, Identifiable {
      case slate, warm, cool, sepia, charcoal, none
      var id: String { rawValue }
      var color: Color { /* per-case Color values */ }
      var displayName: String { /* "Slate", "Warm", ... */ }
  }
  ```
  Suggested colors: `slate` = `Color(red: 0.18, green: 0.20, blue: 0.24)`, `warm` = `Color(red: 0.20, green: 0.13, blue: 0.06)`, `cool` = `Color(red: 0.06, green: 0.12, blue: 0.20)`, `sepia` = `Color(red: 0.22, green: 0.17, blue: 0.10)`, `charcoal` = `Color(red: 0.08, green: 0.08, blue: 0.08)`, `none` = `Color.clear`.
- Wire the picker in `SettingsSheet` to set `AppEnvironment.tintTheme: TintTheme = .charcoal`. `GlassBackground` reads `tintTheme.color` and `tintOpacity` to render the overlay.
- `Services/RecentFilesStore.swift`: `@Observable @MainActor final class` persisting up to 10 file URL paths to `UserDefaults` under key `RecentScripts`. Methods: `add(_ url: URL)`, `remove(_ url: URL)`, `clear()`, `var urls: [URL]`. Filters out URLs whose files no longer exist on read.
- Update main menu: in `SimpleTeleprompterApp`, use `.commands` to add a custom `CommandMenu("File")` with an "Open Recent" submenu populated from `RecentFilesStore`. Each entry's action loads that script via the existing loader. Include a "Clear Menu" item at the bottom.
- When a script is successfully loaded via `ScriptLoader`, call `RecentFilesStore.add(url)`.

**Acceptance**: Settings sheet has a tint theme picker; switching themes smoothly changes the glass tint color. **File → Open Recent** shows previously opened scripts; selecting one loads it.

---

## Phase 8 — Keynote driver mode

**Goal**: When the teleprompter advances to a new slide via `→`, it sends a "show next" command to Keynote. Same for `←` / "show previous".

**Files**:

- `Services/KeynoteController.swift`: `@MainActor final class`.
  - `func isKeynoteRunning() -> Bool` using `NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.iWork.Keynote" }`.
  - `func showNext()` and `func showPrevious()` running `NSAppleScript` with the appropriate command.
  - Dispatch AppleScript execution off the main thread via a private serial `DispatchQueue` to avoid stalling the UI; check errors and log via `Logger`.
  - Optionally: `func startSlideshow()` / `func stopSlideshow()` for future use.
- Add to `AppEnvironment`: `var keynoteSyncEnabled: Bool = true`. Settings sheet exposes a toggle.
- In `TeleprompterEngine.nextSlide()`: if `appEnv.keynoteSyncEnabled && keynoteController.isKeynoteRunning()`, call `keynoteController.showNext()`. Same pattern for `previousSlide()`.
- **Human action required**: in Xcode, **Signing & Capabilities** tab, ensure **Hardened Runtime → Apple Events** is checked, and **Info** tab has `NSAppleEventsUsageDescription` set to `"Simple Teleprompter advances slides in Keynote during presentations."`.

**Acceptance**: Open Keynote with any deck, start its slideshow. Pressing `→` in Simple Teleprompter advances Keynote one slide. First time, macOS will prompt for Apple Events permission — grant it. `←` reverses.

---

## Phase 9 — Persistence, pre-roll countdown, file watcher

**Goal**: v1 polish.

**Files**:

- `Services/PositionStore.swift`: `@MainActor final class`. Stores `(slideIndex: Int, sentenceIndex: Int)` per file URL in `UserDefaults` under key `Positions`, keyed by `url.absoluteString`. Methods: `save(_:for:)`, `load(for:) -> (Int, Int)?`. On successful script load, if `AppEnvironment.resumeEnabled` is true, restore.
- Add to `AppEnvironment`: `var resumeEnabled: Bool = true`. Settings toggle.
- `Views/PreRollOverlay.swift`: shown when `engine.play()` is called and `AppEnvironment.preRollEnabled` is true. Renders a centered glass circle counting down "3 → 2 → 1 → Go" at 1s intervals using `Task.sleep`, then dismisses and the engine begins. Any keypress or click during countdown cancels and returns to paused state.
- Add to `AppEnvironment`: `var preRollEnabled: Bool = false`. Settings toggle (off by default).
- `Services/FileWatcher.swift`: wraps `DispatchSource.makeFileSystemObjectSource(fileDescriptor:eventMask: .write, queue: .main)`. On change, debounces 250ms (via a `Task` that resets on each event), then reloads the script via `ScriptLoader`. Preserves the current slide index, clamped to the new slide count. The current sentence index is reset to 0 of the (possibly new) current slide to avoid pointing into stale content.

**Acceptance**: Reopen a previously loaded script — position is restored. Enable pre-roll, press Space — 3-2-1 countdown plays before scrolling starts. Edit the markdown file in another editor while Simple Teleprompter is open — it reloads within ~300ms preserving the current slide.

---

## After Phase 9

The app is feature-complete for v1. Tag the release:

```
git tag -a v1.0.0 -m "Simple Teleprompter v1.0.0"
```

Next candidates for v1.1+ (not in this plan, but worth noting):
- PowerPoint AppleScript support
- Global hotkeys via `KeyboardShortcuts` for follower mode (Keynote has focus, teleprompter listens system-wide)
- TTS rehearsal mode using `AVSpeechSynthesizer`
- Click-through window mode (cursor passes through to underlying app)
- Notch-aware fullscreen layout on MacBook Pro
- Code Sign + notarize for distribution
