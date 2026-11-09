//
//  FixedQuestion.swift
//  Fatum
//

import Foundation

/// Mirrors the backend's `FixedQuestion` value object (`fatum.catalog.model.vo.FixedQuestion`).
struct FixedQuestion: Codable, Hashable, Identifiable {
    static let maxLength = 50
    /// Choice questions (`QuestionType.requiresOptions`) need at least this many options.
    static let minOptions = 2

    let question: String
    let type: QuestionType
    let options: [String]

    var id: String { "\(question)-\(type.rawValue)" }

    init(question: String, type: QuestionType, options: [String] = []) {
        self.question = Self.formatQuestion(question)
        self.type = type
        if type.requiresOptions {
            var seen = Set<String>()
            self.options = options
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && seen.insert($0).inserted }
        } else {
            self.options = []
        }
    }

    /// Trims and lowercases the question, then capitalizes its first character after
    /// any opening punctuation: "¿TIENES alergias?" → "¿Tienes alergias?".
    /// A question that starts with a number ("2 personas?") is left as is.
    /// The backend still capitalizes the first character
    /// (`_question.trim().lowercase().replaceFirstChar { it.uppercase() }`), so it
    /// needs the same change for both sides to store the same text.
    static func formatQuestion(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let letterIndex = trimmed.firstIndex(where: { $0.isLetter || $0.isNumber }),
              trimmed[letterIndex].isLetter else { return trimmed }
        return trimmed[..<letterIndex]
            + trimmed[letterIndex].uppercased()
            + trimmed[trimmed.index(after: letterIndex)...]
    }

    private enum CodingKeys: String, CodingKey {
        case underscoreQuestion = "_question"
        case question
        case type
        case options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawQuestion = try container.decodeIfPresent(String.self, forKey: .question)
            ?? container.decode(String.self, forKey: .underscoreQuestion)
        let decodedType = try container.decode(QuestionType.self, forKey: .type)
        let decodedOptions = try container.decodeIfPresent([String].self, forKey: .options) ?? []
        self.init(question: rawQuestion, type: decodedType, options: decodedOptions)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode both `_question` (Kotlin constructor property) and `question`
        // so Jackson deserializes the value object properly regardless of property naming config.
        try container.encode(question, forKey: .underscoreQuestion)
        try container.encode(question, forKey: .question)
        try container.encode(type, forKey: .type)
        try container.encode(options, forKey: .options)
    }
}
