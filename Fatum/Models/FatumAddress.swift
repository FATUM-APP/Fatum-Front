import Foundation

/// Mirrors the backend's `AddressDTO` record.
struct FatumAddress: Codable, Equatable, Hashable {
    var residence: String?
    var alias: String?
    var city: String?
    var state: String?
    var country: String?
    var userName: String?

    // MARK: - Capitalized Accessors

    var capitalizedAlias: String? {
        alias?.capitalized
    }

    var capitalizedCity: String? {
        city?.capitalized
    }

    var capitalizedState: String? {
        state?.capitalized
    }

    var capitalizedCountry: String? {
        country?.capitalized
    }

    // MARK: - Display helpers

    /// The value the backend uses to identify this address in the principal and
    /// delete endpoints. The backend always stores an alias, defaulting it to the
    /// residence, so this only falls back for malformed data.
    var identifier: String {
        alias ?? residence ?? ""
    }

    /// `true` when the alias is a real label, not the backend's residence fallback.
    /// Used to avoid printing the same text twice on the card.
    var hasAlias: Bool {
        guard let alias = alias?.trimmingCharacters(in: .whitespacesAndNewlines),
              !alias.isEmpty else { return false }
        return alias.caseInsensitiveCompare(residence ?? "") != .orderedSame
    }

    /// The alias when it is a real label, otherwise the residence line, capitalized per word.
    var displayName: String {
        if hasAlias, let alias { return alias.capitalized }
        return (residence ?? "Dirección").capitalized
    }

    /// "City, State" built from whichever parts are present, capitalized per word.
    var locationLine: String {
        Self.joined([city, state])
    }

    /// "City, Country" built from whichever parts are present, capitalized per word.
    var cityAndCountry: String {
        Self.joined([city, country])
    }

    private static func joined(_ parts: [String?]) -> String {
        parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.capitalized }
            .joined(separator: ", ")
    }

    /// Case-insensitive match against alias, residence, city and state. Empty queries match everything.
    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return [alias, residence, city, state]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }
}
