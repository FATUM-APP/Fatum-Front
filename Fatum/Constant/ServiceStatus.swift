//
//  ServiceStatus.swift
//  Fatum
//

import SwiftUI

/// Mirrors the backend's `ServiceStatus` enum (`fatum.catalog.model.constant.ServiceStatus`).
enum ServiceStatus: String, Codable, CaseIterable {
    case ACTIVE
    case INACTIVE
    case IN_REVIEW
    case SUSPENDED

    /// Label of the status tag on a service card.
    var displayName: String {
        switch self {
        case .ACTIVE: "Activo"
        case .INACTIVE: "Inactivo"
        case .IN_REVIEW: "En revisión"
        case .SUSPENDED: "Suspendido"
        }
    }

    /// Plural label used by the status filter ("Activos", "En revisión"...).
    var filterName: String {
        switch self {
        case .ACTIVE: "Activos"
        case .INACTIVE: "Inactivos"
        case .IN_REVIEW: "En revisión"
        case .SUSPENDED: "Suspendidos"
        }
    }

    /// Background of the status tag; its text uses `.text`.
    var color: Color {
        switch self {
        case .ACTIVE: .fatumAccent
        case .INACTIVE: .inactive
        case .IN_REVIEW, .SUSPENDED: .special
        }
    }

    /// Only active and inactive services can be toggled by the provider;
    /// services in review or suspended are managed by Fatum.
    var canToggleActive: Bool {
        self == .ACTIVE || self == .INACTIVE
    }
}
