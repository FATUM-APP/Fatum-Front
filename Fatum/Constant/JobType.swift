//
//  JobType.swift
//  Fatum
//

import Foundation

enum JobType: String, Codable, CaseIterable {
    case PRESENCIAL

    var displayName: String {
        switch self {
        case .PRESENCIAL: return "Presencial"
        }
    }
}
