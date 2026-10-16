import Foundation

enum Gender: String, Codable, CaseIterable {
    case MALE
    case FEMALE
    case OTHER

    var displayName: String {
        switch self {
        case .MALE: return "Masculino"
        case .FEMALE: return "Femenino"
        case .OTHER: return "Otro"
        }
    }
}
