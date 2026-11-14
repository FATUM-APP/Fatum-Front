//
//  DayScheduleView.swift
//  Fatum
//

import SwiftUI

/// A day's booked slots on a timeline: the hours on the left with a line each,
/// and every slot as a `BookedSlotCard` placed at its time and as tall as it lasts.
///
/// The hours cover `startMinutes` to `endMinutes` (the working hours, 8:00 to
/// 18:00 when missing) and stretch to fit any slot outside them. On today, a
/// line marks the current time.
///
/// `card` draws each slot (usually a `BookedSlotCard`) in the frame of its time.
struct DayScheduleView<Card: View>: View {
    let date: Date
    let slots: [BookedSlot]
    /// Minutes after midnight.
    var startMinutes: Int? = nil
    var endMinutes: Int? = nil
    @ViewBuilder let card: (BookedSlot) -> Card

    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric private var hourHeight: CGFloat = 80
    @ScaledMetric private var minCardHeight: CGFloat = 60
    @ScaledMetric private var hourLabelWidth: CGFloat = 52

    private let calendar = CalendarDate.calendar
    /// Room above the first line and below the last for their labels.
    private let verticalInset: CGFloat = 10

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var dayStart: Date {
        calendar.startOfDay(for: date)
    }

    private var cardsLeading: CGFloat {
        hourLabelWidth + layout.internalSpacing
    }

    /// The hours shown, as hours after midnight.
    private var hours: ClosedRange<Int> {
        let starts = slots.compactMap { $0.start.map(minutes(of:)) }
        let ends = slots.compactMap { $0.end.map(minutes(of:)) }
        let first = min(startMinutes ?? 8 * 60, starts.min() ?? .max) / 60
        let last = (max(endMinutes ?? 18 * 60, ends.max() ?? 0) + 59) / 60
        return first...max(min(last, 24), first + 1)
    }

    var body: some View {
        let hours = hours

        ZStack(alignment: .topLeading) {
            ForEach(Array(hours), id: \.self) { hour in
                hourLine(hour, y: y(forMinutes: hour * 60, in: hours))
            }

            ForEach(slots) { slot in
                card(for: slot, in: hours)
            }

            nowLine(in: hours)
        }
        .frame(height: CGFloat(hours.count - 1) * hourHeight, alignment: .top)
        .padding(.vertical, verticalInset)
    }

    // MARK: - Parts

    private func hourLine(_ hour: Int, y: CGFloat) -> some View {
        HStack(spacing: layout.internalSpacing) {
            Text(hourLabel(hour))
                .fatumStyle(.footer)
                .foregroundStyle(.text.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: hourLabelWidth, alignment: .trailing)

            Rectangle()
                .fill(.border)
                .frame(height: 1)
        }
        // Centered on the line.
        .frame(height: 20)
        .offset(y: y - 10)
        .accessibilityHidden(true)
    }

    private func card(for slot: BookedSlot, in hours: ClosedRange<Int>) -> some View {
        let start = slot.start.map(minutes(of:)) ?? hours.lowerBound * 60
        let end = slot.end.map(minutes(of:)) ?? start + (slot.durationMinutes ?? 60)
        let height = max(y(forMinutes: end, in: hours) - y(forMinutes: start, in: hours), minCardHeight)

        return card(slot)
            .frame(maxWidth: .infinity)
            .frame(height: height - 2)
            .padding(.leading, cardsLeading)
            .offset(y: y(forMinutes: start, in: hours) + 1)
    }

    @ViewBuilder
    private func nowLine(in hours: ClosedRange<Int>) -> some View {
        if calendar.isDateInToday(date) {
            TimelineView(.everyMinute) { context in
                let now = minutes(of: context.date)
                if (hours.lowerBound * 60...hours.upperBound * 60).contains(now) {
                    HStack(spacing: 0) {
                        Circle()
                            .frame(width: 8, height: 8)
                        Rectangle()
                            .frame(height: 1.5)
                    }
                    .foregroundStyle(.fatumAccent)
                    .padding(.leading, cardsLeading - 4)
                    .offset(y: y(forMinutes: now, in: hours) - 4)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Minutes since the start of `date`, clamped to the day (an order ending after midnight stops at 24:00).
    private func minutes(of moment: Date) -> Int {
        min(max(Int(moment.timeIntervalSince(dayStart) / 60), 0), 24 * 60)
    }

    private func y(forMinutes minutes: Int, in hours: ClosedRange<Int>) -> CGFloat {
        CGFloat(minutes - hours.lowerBound * 60) / 60 * hourHeight
    }

    /// "9 a. m.".
    private func hourLabel(_ hour: Int) -> String {
        let moment = calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart
        return moment.formatted(.dateTime.hour().locale(CalendarDate.locale))
    }
}

#Preview {
    ScrollView {
        DayScheduleView(
            date: CalendarDate.date(from: "2026-11-20") ?? .now,
            slots: [
                BookedSlot(orderId: "1", booking: "2026-11-20T10:00", endTime: "2026-11-20T11:00", estimatedTime: 60, status: "ACCEPTED"),
                BookedSlot(orderId: "2", booking: "2026-11-20T12:30", endTime: "2026-11-20T15:00", estimatedTime: 150, status: "PENDING"),
                BookedSlot(orderId: "3", booking: "2026-11-20T15:00", endTime: "2026-11-20T15:45", estimatedTime: 45, status: "DELIVERING")
            ],
            startMinutes: 9 * 60,
            endMinutes: 18 * 60
        ) { slot in
            BookedSlotCard(slot: slot, title: "Maquillaje profesional")
        }
        .padding()
    }
    .background(.brandSecondary)
}
