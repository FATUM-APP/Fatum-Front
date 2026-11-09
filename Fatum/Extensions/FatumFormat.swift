//
//  FatumFormat.swift
//  Fatum
//

import Foundation

/// Text formats shared by the service screens, so prices and times look the
/// same on the create flow, the review screen and the service cards.
enum FatumFormat {
    /// "28.000": Colombian grouping, no decimals.
    static func price(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "es_CO")))
    }

    /// "1h 30m", "2 h", "45 min", or `nil` when there is no positive time.
    static func estimatedTime(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours) h"
    }
}
