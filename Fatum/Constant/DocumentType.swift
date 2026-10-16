import Foundation

enum DocumentType: String, Codable, CaseIterable {
    case ID
    case PASSPORT
    case DRIVING_LICENSE

    var displayName: String {
        switch self {
        case .ID: return "Cédula"
        case .PASSPORT: return "Pasaporte"
        case .DRIVING_LICENSE: return "Licencia de conducción"
        }
    }
}
