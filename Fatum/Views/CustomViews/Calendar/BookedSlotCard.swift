//
//  BookedSlotCard.swift
//  Fatum
//

import SwiftUI

/// One booked order: a bar in the status color (`.special` for accepted and
/// delivering, `.inactive` for pending) on a tint of it, the service title, the
/// duration and the time range. It fills the height it's given, so
/// `DayScheduleView` can make it as tall as the order lasts.
struct BookedSlotCard: View {
    let slot: BookedSlot
    /// The service delivered; `nil` shows a generic title.
    var title: String? = nil
    /// Shows the title as a placeholder while it loads.
    var isLoadingTitle: Bool = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        HStack(spacing: layout.internalSpacing) {
            Capsule()
                .fill(slot.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: layout.tiny) {
                HStack {
                    Text((title ?? "Servicio"))
                        .fatumStyle(.caption)
                        .fontWeight(.bold)
                        .kerning(0.5)
                        .foregroundStyle(.text)
                        .lineLimit(1)
                        .redacted(reason: isLoadingTitle && title == nil ? .placeholder : [])

                    Spacer(minLength: layout.spacingSmall)

                    if let duration {
                        Text(duration)
                            .fatumStyle(.footer)
                            .foregroundStyle(.text)
                            .lineLimit(1)
                    }
                }

                Text(timeRange)
                    .fatumStyle(.caption)
                    .foregroundStyle(.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.vertical, layout.smallPadding)
        .padding(.leading, layout.smallPadding)
        .padding(.trailing, layout.internalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.brandSecondary)
                .overlay(RoundedRectangle(cornerRadius: 14).fill(slot.color.opacity(0.2)))
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityValue(slot.orderStatus?.displayName ?? slot.status)
    }

    /// "10:00 a. m. – 11:00 a. m.".
    private var timeRange: String {
        let style = Date.FormatStyle.dateTime.hour().minute().locale(CalendarDate.locale)
        guard let start = slot.start else { return slot.booking }
        guard let end = slot.end else { return start.formatted(style) }
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }

    /// "45 min", "1 h", "1 h 30 min".
    private var duration: String? {
        guard let minutes = slot.durationMinutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) h"
        default: return "\(hours) h \(rest) min"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        BookedSlotCard(
            slot: BookedSlot(orderId: "1", booking: "2026-11-20T10:00", endTime: "2026-11-20T11:00", estimatedTime: 60, status: "ACCEPTED"),
            title: "Maquillaje profesional"
        )
        BookedSlotCard(
            slot: BookedSlot(orderId: "2", booking: "2026-11-20T14:30", endTime: "2026-11-20T16:00", estimatedTime: nil, status: "PENDING"),
            isLoadingTitle: true
        )
    }
    .padding()
    .background(.brandSecondary)
}
