//
//  SettingsSheet.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import SwiftUI

/// Modal settings dialog opened with `?`.
///
/// Phase 6 wires up the controls. Phase 7 will populate the tint theme
/// picker; Phase 8 wires the Keynote-sync toggle; Phase 9 hooks up the
/// pre-roll countdown.
struct SettingsSheet: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var bindable = appEnv

        Form {
            Section("Playback") {
                LabeledContent("Words per minute") {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(appEnv.engine.wpm) },
                                set: { appEnv.engine.wpm = Int($0.rounded()) }
                            ),
                            in: 60...260,
                            step: 5
                        )
                        Text("\(appEnv.engine.wpm)")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                Toggle("Pre-roll countdown", isOn: $bindable.preRollEnabled)
                Toggle("Auto-resume after scroll", isOn: $bindable.autoResumeAfterScroll)
                Toggle("Resume at last position", isOn: $bindable.resumeEnabled)
            }

            Section("Appearance") {
                LabeledContent("Font size") {
                    HStack {
                        Slider(value: $bindable.fontSize, in: 16...72, step: 1)
                        Text("\(Int(appEnv.fontSize))")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                LabeledContent("Line spacing") {
                    HStack {
                        Slider(value: $bindable.lineSpacing, in: 0...40, step: 1)
                        Text("\(Int(appEnv.lineSpacing))")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                LabeledContent("Tint opacity") {
                    HStack {
                        Slider(value: $bindable.tintOpacity, in: 0...1)
                        Text(String(format: "%.0f%%", appEnv.tintOpacity * 100))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Toggle("Mirror text", isOn: $bindable.isMirrored)
                Picker("Tint theme", selection: $bindable.tintTheme) {
                    ForEach(TintTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
            }

            Section("Reading focus") {
                LabeledContent("Peripheral opacity") {
                    HStack {
                        Slider(value: $bindable.peripheralOpacity, in: 0.1...0.9)
                        Text(String(format: "%.0f%%", appEnv.peripheralOpacity * 100))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                LabeledContent("Fade per sentence") {
                    HStack {
                        Slider(value: $bindable.opacityDropOff, in: 0.0...0.30)
                        Text(String(format: "%.0f%%", appEnv.opacityDropOff * 100))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 560)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
