//
//  OrderStatus.swift
//  Fatum
//

import SwiftUI

/// Mirrors the backend's `OrderStatus` enum (`fatum.catalog.model.constant.OrderStatus`).
enum OrderStatus: String, Codable, CaseIterable {
    case PENDING
    case ACCEPTED
    case REJECTED
    case DELIVERING
    case NOT_DELIVERED
    case COMPLETED
    case CANCELLED
    case DISPUTED
    case SOLVED
    case REFUNDED

    /// Label of the status tag on an order card.
    var displayName: String {
        switch self {
        case .PENDING: "Pendiente"
        case .ACCEPTED: "Aceptada"
        case .REJECTED: "Rechazada"
        case .DELIVERING: "En curso"
        case .NOT_DELIVERED: "No entregada"
        case .COMPLETED: "Completada"
        case .CANCELLED: "Cancelada"
        case .DISPUTED: "En revisión"
        case .SOLVED: "Resuelta"
        case .REFUNDED: "Reembolsada"
        }
    }

    /// One color per status for its tag.
    var color: Color {
        switch self {
        case .PENDING: .orange
        case .ACCEPTED, .DELIVERING: .blue
        case .COMPLETED, .SOLVED: .green
        case .REFUNDED: .purple
        case .REJECTED, .NOT_DELIVERED, .CANCELLED: .red
        case .DISPUTED: .yellow
        }
    }
}

/// The three filters of `OrdersScreen`, each grouping several `OrderStatus`es.
enum OrderFilter: String, CaseIterable {
    case pending = "Pendientes"
    case completed = "Completados"
    case review = "Revisión"

    var statuses: Set<OrderStatus> {
        switch self {
        case .pending: [.PENDING, .ACCEPTED, .DELIVERING]
        case .completed: [.COMPLETED, .REJECTED, .NOT_DELIVERED, .CANCELLED, .SOLVED, .REFUNDED]
        case .review: [.DISPUTED]
        }
    }
}
