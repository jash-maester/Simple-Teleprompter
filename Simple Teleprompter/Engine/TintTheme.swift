//
//  TintTheme.swift
//  Simple Teleprompter
//
//  Created by Jashaswimalya Acharjee on 30/05/26.
//

import SwiftUI

/// Predefined tint colors that ``GlassBackground`` lays over the Liquid
/// Glass layer at ``AppEnvironment/tintOpacity``. The user picks one of
/// these in the settings sheet; `.none` skips the tint entirely so the
/// raw glass shows through.
enum TintTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case charcoal
    case slate
    case warm
    case cool
    case sepia
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .charcoal: return "Charcoal"
        case .slate:    return "Slate"
        case .warm:     return "Warm"
        case .cool:     return "Cool"
        case .sepia:    return "Sepia"
        case .none:     return "None"
        }
    }

    var color: Color {
        switch self {
        case .charcoal: return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .slate:    return Color(red: 0.18, green: 0.20, blue: 0.24)
        case .warm:     return Color(red: 0.20, green: 0.13, blue: 0.06)
        case .cool:     return Color(red: 0.06, green: 0.12, blue: 0.20)
        case .sepia:    return Color(red: 0.22, green: 0.17, blue: 0.10)
        case .none:     return .clear
        }
    }
}
