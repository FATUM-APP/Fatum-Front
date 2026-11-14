//
//  ClientCalendarProvider.swift
//  Fatum
//

import SwiftUI

/// Feeds `ClientCalendarScreen` with the orders the client hired, from
/// `GET /order/client` for ACCEPTED and DELIVERING (pending ones aren't shown
/// to clients). The endpoint has no month filter, so every month loads at once,
/// grouped by booking day. `ClientOrder` has no end, so each slot ends at
/// `booking + estimatedTime` (see `BookedSlot.init(order:)`).
@MainActor
@Observable
class ClientCalendarProvider {
    /// The slots of each day, keyed by its start, earliest first.
    private(set) var slotsByDay: [Date: [BookedSlot]] = [:]
    var isLoading = false
    var error: String? = nil

    private let orderProvider = OrderProvider()

    func slots(on date: Date) -> [BookedSlot] {
        slotsByDay[CalendarDate.calendar.startOfDay(for: date)] ?? []
    }

    /// Returns `false` when a request fails, with the message in `error`.
    func loadOrders(clientId: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let accepted = orderProvider.fetchClientOrders(clientId: clientId, status: .ACCEPTED)
            async let delivering = orderProvider.fetchClientOrders(clientId: clientId, status: .DELIVERING)
            let orders = try await accepted + delivering

            let calendar = CalendarDate.calendar
            slotsByDay = Dictionary(grouping: orders.compactMap(BookedSlot.init(order:))) { slot in
                slot.start.map(calendar.startOfDay(for:)) ?? .distantPast
            }
            .mapValues { $0.sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) } }
            return true
        } catch let decodingError as DecodingError {
            print("DEBUG client calendar decoding error: \(decodingError)")
            error = "La respuesta del servidor no tiene el formato esperado"
            return false
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return true }
            print("DEBUG client calendar error: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }
}
