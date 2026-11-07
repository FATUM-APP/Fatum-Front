import Foundation

/// Mirrors the backend's `ItemResponse` DTO.
/// `fixedQuestions` is not decoded yet; unknown keys are ignored by `JSONDecoder`.
struct FatumItem: Codable, Hashable, Identifiable {
    var id: String?
    var title: String
    var description: String?
    var providerName: String
    var providerUsername: String
    var basePrice: String
    var priceType: String
    var isNegotiable: Bool
    var defaultEstimatedTime: Int?
    var jobType: String
    var category: String

    /// Case-insensitive match against title, description, provider and category. Empty queries match everything.
    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return [title, description, providerName, category]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }
}
