//
//  PriceType.swift
//  Fatum
//

import Foundation

enum PriceType: String, Codable, CaseIterable {
    case FIXED
    case HOURLY

    var displayName: String {
        switch self {
        case .FIXED: return "Precio fijo"
        case .HOURLY: return "Por hora"
        }
    }

    /// Currency label shown next to a price, e.g. "28.000 COP/HORA".
    var unitLabel: String {
        switch self {
        case .FIXED: return "COP"
        case .HOURLY: return "COP/HORA"
        }
    }
}
