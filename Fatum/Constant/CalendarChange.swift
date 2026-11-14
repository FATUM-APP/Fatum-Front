//
//  CalendarChange.swift
//  Fatum
//

import Foundation

/// Mirrors the backend's `CalendarChange`: what changed in a provider's
/// calendar, sent as `change` in the `CALENDAR_CHANGED` events of `/realtime/calendar`.
enum CalendarChange: String, Codable {
    /// An order was created, accepted, rejected, cancelled… `start` and `end` are null.
    case ORDER_UPDATED
    case WEEKLY_SCHEDULE_CHANGED
    case UNAVAILABLE_ADDED
    case UNAVAILABLE_CHANGED
    case UNAVAILABLE_REMOVED
}
