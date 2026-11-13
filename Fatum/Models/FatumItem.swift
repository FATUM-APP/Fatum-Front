import Foundation

/// Mirrors the backend's `ItemResponse` DTO. Photos come from a separate
/// request (`GET /catalog/item/images`).
struct FatumItem: Codable, Hashable, Identifiable {
    var id: String?
    var title: String
    var description: String?
    /// Only for requests (e.g. the provider's public profile); never shown in a view.
    var providerId: String
    var providerName: String
    var providerUsername: String
    var basePrice: String
    var priceType: String
    var isNegotiable: Bool
    var defaultEstimatedTime: Int?
    var jobType: String
    var category: String
    /// Optional so a response without the key still decodes.
    var fixedQuestions: [FixedQuestion]? = nil
    /// Raw `ServiceStatus`; optional so a response without the key still decodes.
    var status: String? = nil

    /// Case-insensitive match against title, description, provider and category. Empty queries match everything.
    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return [title, description, providerName, category]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    // MARK: - Display helpers

    /// "28.000", or the raw value if the backend sends something that isn't a number.
    var formattedPrice: String {
        Decimal(string: basePrice).map(FatumFormat.price) ?? basePrice
    }

    /// "COP" or "COP/HORA".
    var priceUnitLabel: String {
        PriceType(rawValue: priceType)?.unitLabel ?? "COP"
    }

    /// "Presencial", or the raw value for job types the app doesn't know yet.
    var jobTypeDisplay: String {
        JobType(rawValue: jobType)?.displayName ?? jobType.capitalized
    }

    /// "1h 30m", "45 min", or `nil` when the service has no estimated time.
    var estimatedTimeDisplay: String? {
        FatumFormat.estimatedTime(minutes: defaultEstimatedTime)
    }

    /// `nil` when the backend didn't send a status or sent one the app doesn't know.
    var serviceStatus: ServiceStatus? {
        status.flatMap(ServiceStatus.init(rawValue:))
    }
}
