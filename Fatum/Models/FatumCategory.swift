import Foundation

/// Mirrors the backend's `CategoryResponse` DTO.
struct FatumCategory: Codable, Hashable, Identifiable {
    var name: String
    var slug: String
    var parentSlug: String?
    var schedulingModel: String
    var isAble: Bool
    var logoUrl: String?

    var id: String { slug }
}
