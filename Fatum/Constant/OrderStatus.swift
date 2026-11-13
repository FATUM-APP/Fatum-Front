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
}

/// The three steps both parties confirm. Mirrors the `confirmation` of the
/// `ORDER_CONFIRMATION_CHANGED` event; `path` is the segment of
/// `/order/confirm/{path}/{orderId}` and `/order/deny/{path}/{orderId}`.
enum OrderStage: String, Codable {
    case START
    case COMPLETION
    case PAYMENT

    var path: String {
        rawValue.lowercased()
    }
}

/// Mirrors the backend's `ConfirmingParty`, sent as `?party=` and in the events.
enum ConfirmingParty: String, Codable {
    case CUSTOMER
    case PROVIDER
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
