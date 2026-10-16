//
//  SessionReflection.swift
//  NoFeed
//
//  How a finished session felt, in one of three words. This replaced the
//  1–5 dots: a number asked the user to grade themselves, and nobody knew what
//  a 3 meant. Three words describe what happened instead of scoring it, and
//  are what the "What works for you" insights are computed from.
//
//  Raw values are stored in Core Data (`FocusSession.reflectionRaw`) and sent
//  through the notification inbox, so they must never be renumbered.
//

import Foundation

enum SessionReflection: Int16, CaseIterable, Codable {
    case none = 0
    case focused = 1
    case distracted = 2
    case interrupted = 3

    /// The three the user can choose; `none` is the absence of an answer.
    static let choices: [SessionReflection] = [.focused, .distracted, .interrupted]

    var title: String {
        switch self {
        case .none: return String(localized: "Not reflected")
        case .focused: return String(localized: "Focused")
        case .distracted: return String(localized: "Distracted")
        case .interrupted: return String(localized: "Interrupted")
        }
    }

    var symbol: String {
        switch self {
        case .none: return "circle.dashed"
        case .focused: return "checkmark"
        case .distracted: return "arrow.uturn.left"
        case .interrupted: return "bell.slash"
        }
    }

    /// Past tense, for a row in History: "Felt focused".
    var feltLabel: String {
        switch self {
        case .none: return String(localized: "Not reflected")
        case .focused: return String(localized: "Felt focused")
        case .distracted: return String(localized: "Felt distracted")
        case .interrupted: return String(localized: "Was interrupted")
        }
    }

    /// Sessions rated under the old 1–5 dots keep their meaning: the low end
    /// was a distracted session, the middle an interrupted one, the top focused.
    /// Pure, so the mapping has a test and never needs a data migration.
    static func fromLegacyRating(_ rating: Int16) -> SessionReflection {
        switch rating {
        case 1, 2: return .distracted
        case 3: return .interrupted
        case 4, 5: return .focused
        default: return .none
        }
    }
}
