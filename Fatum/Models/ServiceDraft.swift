//
//  ServiceDraft.swift
//  Fatum
//

import UIKit

/// Form state of the "Ofrecer servicio" flow, shared by `CreateServiceScreen`
/// and `ServiceReviewScreen`. Text fields are kept exactly as typed;
/// `request(providerId:)` trims and parses them into the backend's `CreateServiceRequest`.
struct ServiceDraft {
    static let minPhotos = 1
    static let maxPhotos = 10

    var title: String = ""
    var descriptionText: String = ""
    var basePriceText: String = ""
    var priceType: PriceType = .FIXED
    var isNegotiable: Bool = false
    var estimatedTimeText: String = ""
    var category: FatumCategory? = nil
    var fixedQuestions: [FixedQuestion] = []
    var images: [UIImage] = []

    // MARK: - Parsed values

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDescription: String {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// An empty field means 0, as the backend defaults it. `nil` when the text isn't a valid number.
    var basePrice: Decimal? {
        let trimmed = basePriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        guard let value = Decimal(string: trimmed), value >= 0 else { return nil }
        return value
    }

    /// Minutes, or `nil` when the optional field is empty.
    var estimatedTime: Int? {
        Int(estimatedTimeText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Validation

    var hasValidInfo: Bool {
        !trimmedTitle.isEmpty
    }

    var hasValidPricing: Bool {
        basePrice != nil
    }

    var hasValidDetails: Bool {
        let trimmedTime = estimatedTimeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmedTime.isEmpty || estimatedTime != nil) && category != nil
    }

    var hasValidPhotos: Bool {
        (Self.minPhotos...Self.maxPhotos).contains(images.count)
    }

    var isComplete: Bool {
        hasValidInfo && hasValidPricing && hasValidDetails && hasValidPhotos
    }

    // MARK: - Display helpers

    /// "1h 30m", "2 h", "45 min" or "No especificado".
    var estimatedTimeDisplay: String {
        guard let minutes = estimatedTime, minutes > 0 else { return "No especificado" }
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours) h"
    }

    // MARK: - Request

    /// The JPEG files sent as the `images` part of the request.
    var imageData: [Data] {
        images.compactMap { $0.jpegData(compressionQuality: 0.8) }
    }

    /// Builds the request body, or `nil` while the draft is incomplete.
    func request(providerId: String) -> CatalogProvider.CreateServiceRequest? {
        guard isComplete, let basePrice, let category else { return nil }
        return CatalogProvider.CreateServiceRequest(
            providerId: providerId,
            title: trimmedTitle,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            basePrice: basePrice,
            priceType: priceType,
            isNegotiable: isNegotiable,
            defaultEstimatedTime: estimatedTime,
            category: category.name,
            fixedQuestions: fixedQuestions
        )
    }
}
