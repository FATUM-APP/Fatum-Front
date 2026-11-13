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
    static let uploadCompressionQuality: CGFloat = 0.8

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
    /// The field shows thousands grouped with dots ("50.000"), so they are removed first.
    var basePrice: Decimal? {
        let trimmed = basePriceText
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        FatumFormat.estimatedTime(minutes: estimatedTime) ?? "No especificado"
    }

    // MARK: - Request

    /// The JPEG files sent as the `images` part of the request, at full resolution.
    var imageData: [Data] {
        images.compactMap { $0.jpegData(compressionQuality: Self.uploadCompressionQuality) }
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

    /// Same checks as `isComplete` except the category, which can't change after publishing.
    var isCompleteForUpdate: Bool {
        let trimmedTime = estimatedTimeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return hasValidInfo && hasValidPricing && hasValidPhotos
            && (trimmedTime.isEmpty || estimatedTime != nil)
    }

    /// Builds the body of `PUT /catalog/item/update` for service `id`, or `nil`
    /// while the draft is incomplete. Only the fields that differ from `original`
    /// (the service as it was loaded) are sent. The backend always applies
    /// `defaultEstimatedTime` and `fixedQuestions`, so those always carry the current value.
    func updateRequest(id: String, original: ServiceDraft) -> CatalogProvider.UpdateServiceRequest? {
        guard isCompleteForUpdate, let basePrice else { return nil }
        var request = CatalogProvider.UpdateServiceRequest(
            id: id,
            defaultEstimatedTime: estimatedTime,
            fixedQuestions: fixedQuestions
        )
        // The backend checks that a new title isn't already used by this provider,
        // so an unchanged title must not be sent.
        if trimmedTitle != original.trimmedTitle {
            request.title = trimmedTitle
        }
        // "" clears the description.
        if trimmedDescription != original.trimmedDescription {
            request.description = trimmedDescription
        }
        if basePrice != original.basePrice {
            request.basePrice = basePrice
        }
        if priceType != original.priceType {
            request.priceType = priceType
        }
        if isNegotiable != original.isNegotiable {
            request.isNegotiable = isNegotiable
        }
        return request
    }
}

// MARK: - Existing services

extension ServiceDraft {
    /// A draft filled with a published service, to show or edit it.
    /// `category` is the `FatumCategory` whose slug is `item.category`, if it's known.
    init(item: FatumItem, category: FatumCategory?, images: [UIImage]) {
        self.init(
            title: item.title,
            descriptionText: item.description ?? "",
            // Same "50.000" grouping the price field shows while typing.
            basePriceText: Decimal(string: item.basePrice).map(FatumFormat.price) ?? "",
            priceType: PriceType(rawValue: item.priceType) ?? .FIXED,
            isNegotiable: item.isNegotiable,
            estimatedTimeText: item.defaultEstimatedTime.map(String.init) ?? "",
            category: category,
            fixedQuestions: item.fixedQuestions ?? [],
            images: images
        )
    }
}
