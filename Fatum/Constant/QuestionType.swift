//
//  QuestionType.swift
//  Fatum
//

import Foundation

enum QuestionType: String, Codable, CaseIterable {
    case TEXT
    case BOOLEAN
    case SINGLE_CHOICE
    case MULTIPLE_CHOICE

    var displayName: String {
        switch self {
        case .TEXT: return "Texto"
        case .BOOLEAN: return "Sí / No"
        case .SINGLE_CHOICE: return "Selección única"
        case .MULTIPLE_CHOICE: return "Selección múltiple"
        }
    }

    /// `true` for the types whose answer is picked from `FixedQuestion.options`.
    var requiresOptions: Bool {
        self == .SINGLE_CHOICE || self == .MULTIPLE_CHOICE
    }
}
