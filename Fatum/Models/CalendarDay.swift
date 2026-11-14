//
//  CalendarDay.swift
//  Fatum
//

import SwiftUI

/// Mirrors the backend's `CalendarDay` from `GET /provider/calendar`: one day of
/// the provider's month with its working hours and the orders booked on it.
/// Dates and times stay as the backend's strings (`LocalDate`, `LocalTime`) and
/// are read through the computed properties.
struct CalendarDay: Decodable, Hashable {
    /// `LocalDate`, e.g. "2026-11-20".
    let date: String
    let isAvailable: Bool
    /// `LocalTime`, e.g. "09:00:00"; start of the working hours.
    let initialTime: String?
    /// `LocalTime`, e.g. "18:00:00"; end of the working hours.
    let finalTime: String?
    let unavailableReason: String?
    let bookedSlots: [BookedSlot]

    private enum CodingKeys: String, CodingKey {
        case date, isAvailable, initialTime, finalTime, unavailableReason, bookedSlots
    }

    init(
        date: String,
        isAvailable: Bool,
        initialTime: String? = nil,
        finalTime: String? = nil,
        unavailableReason: String? = nil,
        bookedSlots: [BookedSlot] = []
    ) {
        self.date = date
        self.isAvailable = isAvailable
        self.initialTime = initialTime
        self.finalTime = finalTime
        self.unavailableReason = unavailableReason
        self.bookedSlots = bookedSlots
    }

    /// `bookedSlots` defaults to an empty list in the backend, so it may be missing.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
        initialTime = try container.decodeIfPresent(String.self, forKey: .initialTime)
        finalTime = try container.decodeIfPresent(String.self, forKey: .finalTime)
        unavailableReason = try container.decodeIfPresent(String.self, forKey: .unavailableReason)
        bookedSlots = try container.decodeIfPresent([BookedSlot].self, forKey: .bookedSlots) ?? []
    }

    /// Start of the day in the device's time zone.
    var day: Date? {
        CalendarDate.date(from: date)
    }

    /// Minutes after midnight when the working hours start.
    var startMinutes: Int? {
        initialTime.flatMap(CalendarDate.minutes(from:))
    }

    /// Minutes after midnight when the working hours end.
    var endMinutes: Int? {
        finalTime.flatMap(CalendarDate.minutes(from:))
    }
}

/// Mirrors the backend's `BookedSlot`: an order taking part of a calendar day.
struct BookedSlot: Decodable, Hashable, Identifiable {
    let orderId: String
    /// `LocalDateTime`, e.g. "2026-11-20T10:00".
    let booking: String
    /// `LocalDateTime`, e.g. "2026-11-20T11:00".
    let endTime: String
    /// Minutes.
    let estimatedTime: Int?
    /// Kept as a `String` so a new status doesn't break decoding.
    let status: String
    /// Not in the backend's `BookedSlot`: the client's calendar fills it from
    /// `ClientOrder.catalogItemTitle`; the provider's loads it from `GET /order/{id}`.
    var serviceTitle: String? = nil

    private enum CodingKeys: String, CodingKey {
        case orderId, booking, endTime, estimatedTime, status
    }

    /// Minutes an order lasts when it has no estimated time.
    static let defaultMinutes = 60

    init(orderId: String, booking: String, endTime: String, estimatedTime: Int?, status: String, serviceTitle: String? = nil) {
        self.orderId = orderId
        self.booking = booking
        self.endTime = endTime
        self.estimatedTime = estimatedTime
        self.status = status
        self.serviceTitle = serviceTitle
    }

    /// A client's order as a slot. `ClientOrder` has no end, so it's
    /// `booking + estimatedTime` (`defaultMinutes` when there's none).
    init?(order: FatumOrder) {
        guard let orderId = order.id,
              let start = CalendarDate.date(from: order.booking),
              let end = CalendarDate.calendar.date(byAdding: .minute, value: order.estimatedTime ?? Self.defaultMinutes, to: start)
        else { return nil }
        self.init(
            orderId: orderId,
            booking: order.booking,
            endTime: CalendarDate.localDateTime(end),
            estimatedTime: order.estimatedTime,
            status: order.status,
            serviceTitle: order.catalogItemTitle
        )
    }

    var id: String { orderId }

    var orderStatus: OrderStatus? {
        OrderStatus(rawValue: status)
    }

    var start: Date? {
        CalendarDate.date(from: booking)
    }

    var end: Date? {
        CalendarDate.date(from: endTime)
    }

    /// `estimatedTime`, or the time between `booking` and `endTime` when it's missing.
    var durationMinutes: Int? {
        if let estimatedTime { return estimatedTime }
        guard let start, let end else { return nil }
        return Int(end.timeIntervalSince(start) / 60)
    }

    /// Accepted and delivering orders use `.special`, pending ones `.inactive`.
    var color: Color {
        orderStatus == .PENDING ? .inactive : .special
    }
}

/// Reads the backend's `LocalDate`, `LocalDateTime` and `LocalTime` strings in
/// the device's time zone, and holds the calendar every calendar view shares
/// (weeks start on Monday, Spanish names).
enum CalendarDate {
    static let locale = Locale(identifier: "es_CO")

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.firstWeekday = 2
        return calendar
    }()

    /// "2026-11-20" or "2026-11-20T10:00[:00]". Seconds are ignored.
    static func date(from value: String) -> Date? {
        let numbers = numbers(in: value)
        guard numbers.count >= 3 else { return nil }
        var components = DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])
        if numbers.count >= 5 {
            components.hour = numbers[3]
            components.minute = numbers[4]
        }
        return calendar.date(from: components)
    }

    /// "09:00[:00]" as minutes after midnight.
    static func minutes(from time: String) -> Int? {
        let numbers = numbers(in: time)
        guard numbers.count >= 2 else { return nil }
        return numbers[0] * 60 + numbers[1]
    }

    /// `date` as a `LocalDate`, e.g. "2026-11-20".
    static func localDate(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// `date` as a `LocalDateTime`, e.g. "2026-11-20T10:00".
    static func localDateTime(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return localDate(date) + String(format: "T%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func numbers(in value: String) -> [Int] {
        value.split { !$0.isNumber }.compactMap { Int($0) }
    }
}
