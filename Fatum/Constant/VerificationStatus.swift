import Foundation

/// Mirrors the backend's `VerificationStatus` enum.
/// Unknown values decode as `.UNVERIFIED` so a new backend state never breaks login.
enum VerificationStatus: String, Codable {
    case UNVERIFIED
    case VERIFIED
    case REJECTED
    case MANUAL_REVIEW

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = VerificationStatus(rawValue: rawValue) ?? .UNVERIFIED
    }

    var displayName: String {
        switch self {
        case .UNVERIFIED: return "Sin verificar"
        case .VERIFIED: return "Verificado"
        case .REJECTED: return "Rechazado"
        case .MANUAL_REVIEW: return "En revisión manual"
        }
    }
}
