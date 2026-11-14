//
//  CalendarScreen.swift
//  Fatum
//

import SwiftUI

/// Root of the "Calendario" tab for professionals: their month from
/// `GET /provider/calendar` with a dot per order (pending in `.inactive`,
/// accepted and delivering in `.special`). Clients get `ClientCalendarScreen`.
///
/// Selecting a day collapses `MonthCalendarView` to that week and the day's
/// orders slide in below on a `DayScheduleView`; tapping one opens
/// `OrderDetailSheet`. Each month loads when shown.
///
/// While it's open it listens to `/realtime/calendar`, so new orders, status
/// changes and schedule or unavailability changes show up without pulling to refresh.
///
/// With `side`, a `CalendarSideMenu` at the top left switches to `ClientCalendarScreen`.
struct CalendarScreen: View {
    var side: Binding<ConfirmingParty>? = nil

    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var calendarProvider = CalendarProvider()
    @State private var month = Date()
    @State private var selectedDate: Date? = nil
    @State private var slotToShow: BookedSlot? = nil
    @State private var showToast = false
    @State private var toastMessage = ""

    private let calendar = CalendarDate.calendar

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// Reloads when the month (not just the day) changes.
    private var monthKey: Int {
        calendar.component(.year, from: month) * 100 + calendar.component(.month, from: month)
    }

    private var dots: [Date: [Color]] {
        calendarProvider.days.keys.reduce(into: [:]) { dots, date in
            dots[date] = calendarProvider.slots(on: date).map(\.color)
        }
    }

    private var unavailableDates: Set<Date> {
        Set(calendarProvider.days.filter { !$0.value.isAvailable }.keys)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.spacingMedium) {
                if calendarProvider.isLoading || side != nil {
                    HStack(spacing: layout.internalSpacing) {
                        if let side {
                            CalendarSideMenu(side: side)
                        }

                        Spacer()

                        if calendarProvider.isLoading {
                            ProgressView()
                                .tint(.brandPrimary)
                        }
                    }
                }

                MonthCalendarView(
                    month: $month,
                    selectedDate: $selectedDate,
                    dots: dots,
                    dimmedDates: unavailableDates
                )

                if let selectedDate {
                    daySection(for: selectedDate)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .screenPadding()
        }
        .background(.brandSecondary)
        .refreshable {
            await loadMonth()
        }
        .overlay(alignment: .bottom) {
            if showToast {
                ToastMessageView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showToast)
        // Changing months quickly cancels the previous request.
        .task(id: monthKey) {
            await loadMonth()
        }
        // Cancelled when the screen goes away, which closes the stream.
        .task(id: userProvider.currentUser?.userId) {
            guard let providerId = userProvider.currentUser?.userId else { return }
            await calendarProvider.listenForEvents(providerId: providerId)
        }
        // A realtime reload diffs this day's orders to highlight the new ones.
        .onChange(of: selectedDate, initial: true) {
            calendarProvider.visibleDay = selectedDate
        }
        .sheet(item: $slotToShow) { slot in
            OrderDetailSheet(orderId: slot.orderId, initialDetail: calendarProvider.details[slot.orderId])
        }
    }

    // MARK: - Day

    @ViewBuilder
    private func daySection(for date: Date) -> some View {
        let day = calendarProvider.day(for: date)
        let slots = calendarProvider.slots(on: date)

        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            

            if let day, !day.isAvailable {
                unavailableNote(reason: day.unavailableReason)
            }

            if slots.isEmpty {
                Text("No tienes órdenes para este día")
                    .fatumStyle(.body)
                    .foregroundStyle(.text.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.padding)
            } else {
                DayScheduleView(
                    date: date,
                    slots: slots,
                    startMinutes: day?.startMinutes,
                    endMinutes: day?.endMinutes
                ) { slot in
                    Button {
                        slotToShow = slot
                    } label: {
                        BookedSlotCard(
                            slot: slot,
                            title: calendarProvider.serviceTitle(of: slot),
                            isLoadingTitle: calendarProvider.loadingDetailIds.contains(slot.orderId)
                        )
                        // Orders that just arrived through `/realtime/calendar`.
                        .overlay {
                            if calendarProvider.highlightedOrderIds.contains(slot.orderId) {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.fatumAccent, lineWidth: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Ver detalle de la orden")
                }
            }
        }
        // The slots only carry the order id; their titles come from `GET /order/{id}`.
        .task(id: slots.map(\.orderId)) {
            await calendarProvider.loadDetails(for: slots)
        }
    }

    private func unavailableNote(reason: String?) -> some View {
        HStack(spacing: layout.internalSpacing) {
            Text("No disponible")
                .fatumStyle(.footer)
                .foregroundStyle(.text)
                .padding(layout.smallPadding)
                .background(.inactive, in: RoundedRectangle(cornerRadius: 12))

            if let reason, !reason.isEmpty {
                Text(reason)
                    .fatumStyle(.footer)
                    .foregroundStyle(.text.opacity(0.7))
            }
        }
    }

    // MARK: - Load

    private func loadMonth() async {
        guard let providerId = userProvider.currentUser?.userId else { return }
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let year = components.year, let monthNumber = components.month else { return }

        // Only errors get a toast.
        if await !calendarProvider.loadMonth(providerId: providerId, year: year, month: monthNumber) {
            showMessage(calendarProvider.error ?? "No se pudo cargar el calendario")
        }
    }

    private func showMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }
}

#Preview {
    CalendarScreen()
        .environment(UserProvider())
}
