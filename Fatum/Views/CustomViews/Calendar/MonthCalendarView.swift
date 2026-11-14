//
//  MonthCalendarView.swift
//  Fatum
//

import SwiftUI

/// A month grid starting on Monday. The chevrons move one month and tapping the
/// title opens wheels to jump to any month and year. Each day can show small
/// dots below its number (`dots`), e.g. one per order.
///
/// Selecting a day collapses the grid to that day's week: the other weeks fade
/// out and the selected one slides to the top, making room for whatever the
/// screen shows below. While collapsed the chevrons move one week. Tapping the
/// selected day again or the handle at the bottom expands the month back.
struct MonthCalendarView: View {
    /// Any date inside the month shown.
    @Binding var month: Date
    @Binding var selectedDate: Date?
    /// Dot colors of each day, keyed by the start of the day.
    var dots: [Date: [Color]] = [:]
    /// Days of the month drawn faded, e.g. the provider doesn't work them. Keyed by the start of the day.
    var dimmedDates: Set<Date> = []
    var maxDots = 3

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Namespace private var selection
    @State private var showMonthPicker = false

    private let calendar = CalendarDate.calendar
    private let animation: Animation = .spring(duration: 0.45, bounce: 0.15)

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var cellSize: CGFloat {
        sizeClass == .compact ? 44 : 56
    }

    private var isCollapsed: Bool {
        selectedDate != nil
    }

    var body: some View {
        VStack(spacing: layout.internalSpacing) {
            header
            weekdayRow

            VStack(spacing: layout.spacingSmall) {
                ForEach(weeks, id: \.self) { week in
                    if !isCollapsed || week.contains(where: isSelected) {
                        weekRow(week)
                            .transition(.opacity)
                    }
                }
            }

            if isCollapsed {
                expandHandle
                    .transition(.opacity)
            }
        }
        .padding(layout.internalPadding)
        .background(.secondaryContainer, in: RoundedRectangle(cornerRadius: 24))
        .onChange(of: month) { _, newMonth in
            // E.g. a month picked with the wheels: a selection outside it would hide every week.
            if let selectedDate, !calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
                withAnimation(animation) { self.selectedDate = nil }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            chevron("chevron.left", label: isCollapsed ? "Semana anterior" : "Mes anterior") { shift(by: -1) }

            Spacer()

            Button {
                showMonthPicker = true
            } label: {
                HStack(spacing: layout.spacingSmall) {
                    Text(title)
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.text)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Elegir mes y año")
            .popover(isPresented: $showMonthPicker) {
                MonthYearPicker(month: $month)
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            chevron("chevron.right", label: isCollapsed ? "Semana siguiente" : "Mes siguiente") { shift(by: 1) }
        }
    }

    private func chevron(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .fontWeight(.semibold)
                .foregroundStyle(.text)
                .frame(width: 36, height: 36)
                .background(.brandSecondary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// "Noviembre 2026".
    private var title: String {
        let index = calendar.component(.month, from: month) - 1
        let name = calendar.standaloneMonthSymbols[index].capitalized(with: CalendarDate.locale)
        return "\(name) \(calendar.component(.year, from: month))"
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .fatumStyle(.footer)
                    .foregroundStyle(.text)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// "Lun", "Mar"… starting on the calendar's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols.map {
            $0.replacingOccurrences(of: ".", with: "").capitalized(with: CalendarDate.locale)
        }
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    // MARK: - Grid

    /// The month's weeks, filled with the days of the months around it.
    private var weeks: [[Date]] {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start,
              let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let rows = (leading + daysInMonth + 6) / 7

        return (0..<rows).map { row in
            (0..<7).compactMap { column in
                calendar.date(byAdding: .day, value: row * 7 + column - leading, to: start)
                    .map(calendar.startOfDay(for:))
            }
        }
    }

    private func weekRow(_ week: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(week, id: \.self) { date in
                dayCell(date)
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isInMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let isSelected = isSelected(date)
        let isToday = calendar.isDateInToday(date)
        let colors = Array((dots[date] ?? []).prefix(maxDots))
        let count = dots[date]?.count ?? 0

        return Button {
            select(date)
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .fatumStyle(.body)
                    .fontWeight(isSelected || isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? Color.brandSecondary : isToday ? Color.fatumAccent : Color.text)

                HStack(spacing: 3) {
                    ForEach(colors.indices, id: \.self) { index in
                        Capsule()
                            .fill(colors[index])
                            .frame(width: 8, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(width: cellSize, height: cellSize)
            .background {
                if isSelected {
                    Circle()
                        .fill(.brandPrimary)
                        .matchedGeometryEffect(id: "selection", in: selection)
                }
            }
            .opacity(isInMonth ? (dimmedDates.contains(date) ? 0.45 : 1) : 0.3)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(CalendarDate.locale)))
        .accessibilityValue(count == 0 ? "" : count == 1 ? "1 orden" : "\(count) órdenes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var expandHandle: some View {
        Button {
            withAnimation(animation) { selectedDate = nil }
        } label: {
            Image(systemName: "chevron.compact.down")
                .font(.title2)
                .foregroundStyle(.text)
                .frame(maxWidth: .infinity, minHeight: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ver mes completo")
    }

    // MARK: - Actions

    private func isSelected(_ date: Date) -> Bool {
        selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
    }

    /// Tapping the selected day deselects it; a day of another month also moves to that month.
    private func select(_ date: Date) {
        withAnimation(animation) {
            if isSelected(date) {
                selectedDate = nil
            } else {
                selectedDate = date
                if !calendar.isDate(date, equalTo: month, toGranularity: .month) {
                    month = date
                }
            }
        }
    }

    /// One week while collapsed (the selection moves with it), one month otherwise.
    private func shift(by value: Int) {
        withAnimation(animation) {
            if let selectedDate {
                guard let date = calendar.date(byAdding: .day, value: value * 7, to: selectedDate) else { return }
                self.selectedDate = date
                month = date
            } else if let date = calendar.date(byAdding: .month, value: value, to: month) {
                month = date
            }
        }
    }
}

/// Month and year wheels shown from the calendar's title.
private struct MonthYearPicker: View {
    @Binding var month: Date

    private let calendar = CalendarDate.calendar

    private var years: [Int] {
        let current = calendar.component(.year, from: .now)
        let shown = calendar.component(.year, from: month)
        return Array(min(current - 2, shown)...max(current + 3, shown))
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Mes", selection: component(.month)) {
                ForEach(Array(calendar.standaloneMonthSymbols.enumerated()), id: \.offset) { index, name in
                    Text(name.capitalized(with: CalendarDate.locale)).tag(index + 1)
                }
            }
            Picker("Año", selection: component(.year)) {
                ForEach(years, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 300, height: 200)
        .padding(.horizontal)
    }

    /// The month or the year of `month`, always on the first day.
    private func component(_ component: Calendar.Component) -> Binding<Int> {
        Binding(
            get: { calendar.component(component, from: month) },
            set: { value in
                var components = calendar.dateComponents([.year, .month], from: month)
                components.setValue(value, for: component)
                components.day = 1
                if let date = calendar.date(from: components) { month = date }
            }
        )
    }
}

#Preview {
    @Previewable @State var month = Date()
    @Previewable @State var selectedDate: Date? = nil
    let today = CalendarDate.calendar.startOfDay(for: .now)
    let tomorrow = CalendarDate.calendar.date(byAdding: .day, value: 1, to: today) ?? today

    VStack {
        MonthCalendarView(
            month: $month,
            selectedDate: $selectedDate,
            dots: [today: [.special, .inactive], tomorrow: [.special]]
        )
        Spacer()
    }
    .padding()
    .background(.brandSecondary)
}

#Preview("Día seleccionado") {
    @Previewable @State var month = Date()
    @Previewable @State var selectedDate: Date? = CalendarDate.calendar.startOfDay(for: .now)

    VStack {
        MonthCalendarView(
            month: $month,
            selectedDate: $selectedDate,
            dots: [CalendarDate.calendar.startOfDay(for: .now): [.special, .inactive]]
        )
        Spacer()
    }
    .padding()
    .background(.brandSecondary)
}
