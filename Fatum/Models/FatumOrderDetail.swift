//
//  FatumOrderDetail.swift
//  Fatum
//

import Foundation

/// Mirrors the backend's `OrderDTO` (`GET /order/{id}`): the full order, with
/// both parties, the delivery address, the answers and the requirements.
/// `OrdersScreen` uses it to refresh a single card after an event or an action.
struct FatumOrderDetail: Decodable, Hashable {
    /// Mirrors the backend's `QuestionAnswer`.
    struct Answer: Decodable, Hashable {
        let question: String
        let answer: Set<String>
    }

    let id: String?
    let serviceTitle: String
    /// `LocalDateTime` strings, like `FatumOrder.booking`.
    let createdAt: String
    let updatedAt: String
    let clientId: String
    let clientName: String
    let clientUsername: String
    let providerId: String
    let providerName: String
    let providerUsername: String
    let catalogItemId: String?
    let booking: String
    let negotiatedPrice: String
    let estimatedTime: Int?
    let deliveryCity: String
    let deliveryState: String
    let deliveryCountry: String
    let deliveryResidence: String
    let answers: Set<Answer>
    let requirements: String?
    let deliveryStartedAt: String?
    let startConfirmation: FatumOrder.DualConfirmation
    let completionConfirmation: FatumOrder.DualConfirmation
    let paymentConfirmation: FatumOrder.DualConfirmation
    let reason: String?
    let status: String
}
