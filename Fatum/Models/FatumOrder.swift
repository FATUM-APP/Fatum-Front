//
//  FatumOrder.swift
//  Fatum
//

import Foundation

/// One order as listed in `OrdersScreen`. Decodes both the backend's
/// `ProviderOrder` (`clientUsername`) and `ClientOrder` (`providerUsername`):
/// either one ends up in `counterpartUsername`, the other person in the order.
struct FatumOrder: Decodable, Hashable, Identifiable {
    /// Mirrors the backend's `DualConfirmationResponse`: whether the customer
    /// and the provider confirmed a step of the order (`nil` = not answered yet).
    struct DualConfirmation: Decodable, Hashable {
        var byCustomer: Bool? = nil
        var byProvider: Bool? = nil
    }

    let id: String?
    let counterpartUsername: String
    let catalogItemTitle: String
    /// `LocalDateTime` as sent by the backend, e.g. "2026-11-25T14:30:00".
    let booking: String
    let negotiatedPrice: String
    let estimatedTime: Int?
    var startConfirmation = DualConfirmation()
    var completionConfirmation = DualConfirmation()
    var paymentConfirmation = DualConfirmation()
    /// `var` so realtime events can update the card before the list reloads.
    var reason: String?
    var status: String

    private enum CodingKeys: String, CodingKey {
        case id, clientUsername, providerUsername, catalogItemTitle, booking
        case negotiatedPrice, estimatedTime, reason, status
        case startConfirmation, completionConfirmation, paymentConfirmation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        counterpartUsername = try container.decodeIfPresent(String.self, forKey: .clientUsername)
            ?? container.decode(String.self, forKey: .providerUsername)
        catalogItemTitle = try container.decode(String.self, forKey: .catalogItemTitle)
        booking = try container.decode(String.self, forKey: .booking)
        negotiatedPrice = try container.decode(String.self, forKey: .negotiatedPrice)
        estimatedTime = try container.decodeIfPresent(Int.self, forKey: .estimatedTime)
        startConfirmation = try container.decode(DualConfirmation.self, forKey: .startConfirmation)
        completionConfirmation = try container.decode(DualConfirmation.self, forKey: .completionConfirmation)
        paymentConfirmation = try container.decode(DualConfirmation.self, forKey: .paymentConfirmation)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        status = try container.decode(String.self, forKey: .status)
    }

    init(
        id: String?,
        counterpartUsername: String,
        catalogItemTitle: String,
        booking: String,
        negotiatedPrice: String,
        estimatedTime: Int?,
        reason: String? = nil,
        status: String
    ) {
        self.id = id
        self.counterpartUsername = counterpartUsername
        self.catalogItemTitle = catalogItemTitle
        self.booking = booking
        self.negotiatedPrice = negotiatedPrice
        self.estimatedTime = estimatedTime
        self.reason = reason
        self.status = status
    }

    /// The card of `detail` as `side` sees it: the other party's username.
    init(detail: FatumOrderDetail, side: ConfirmingParty) {
        self.init(
            id: detail.id,
            counterpartUsername: side == .PROVIDER ? detail.clientUsername : detail.providerUsername,
            catalogItemTitle: detail.serviceTitle,
            booking: detail.booking,
            negotiatedPrice: detail.negotiatedPrice,
            estimatedTime: detail.estimatedTime,
            reason: detail.reason,
            status: detail.status
        )
        startConfirmation = detail.startConfirmation
        completionConfirmation = detail.completionConfirmation
        paymentConfirmation = detail.paymentConfirmation
    }

    // MARK: - Confirmations

    func confirmation(for stage: OrderStage) -> DualConfirmation {
        switch stage {
        case .START: startConfirmation
        case .COMPLETION: completionConfirmation
        case .PAYMENT: paymentConfirmation
        }
    }

    /// `party`'s answer for `stage`: `true` confirmed, `false` denied, `nil` not answered.
    func answer(of party: ConfirmingParty, for stage: OrderStage) -> Bool? {
        let confirmation = confirmation(for: stage)
        return party == .CUSTOMER ? confirmation.byCustomer : confirmation.byProvider
    }

    /// Sets `party`'s answer for `stage`, as an `ORDER_CONFIRMATION_CHANGED` event reports it.
    mutating func setAnswer(_ confirmed: Bool, of party: ConfirmingParty, for stage: OrderStage) {
        var updated = confirmation(for: stage)
        if party == .CUSTOMER {
            updated.byCustomer = confirmed
        } else {
            updated.byProvider = confirmed
        }
        switch stage {
        case .START: startConfirmation = updated
        case .COMPLETION: completionConfirmation = updated
        case .PAYMENT: paymentConfirmation = updated
        }
    }

    // MARK: - Display helpers

    /// `nil` when the backend sent a status the app doesn't know.
    var orderStatus: OrderStatus? {
        OrderStatus(rawValue: status)
    }

    /// "50.000", or the raw value if the backend sends something that isn't a number.
    var formattedPrice: String {
        Decimal(string: negotiatedPrice).map(FatumFormat.price) ?? negotiatedPrice
    }

    /// "1h 30m", "45 min", or `nil` when the order has no estimated time.
    var estimatedTimeDisplay: String? {
        FatumFormat.estimatedTime(minutes: estimatedTime)
    }

    /// `booking` read in the device's time zone (`LocalDateTime` has none).
    /// Fractional seconds are dropped; seconds are optional.
    var bookingDate: Date? {
        let trimmed = booking.split(separator: ".").first.map(String.init) ?? booking
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}
