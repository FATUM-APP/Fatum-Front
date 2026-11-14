//
//  ClientCalendarScreen.swift
//  Fatum
//

import SwiftUI

/// Root of the "Calendario" tab for clients: the orders they hired that are
/// accepted or being delivered, as `.special` dots on the month (see
/// `ClientCalendarProvider`). Professionals get `CalendarScreen`.
///
/// Like it, selecting a day collapses `MonthCalendarView` to that week and the
/// day's orders slide in below on a `DayScheduleView`; tapping one opens
/// `OrderDetailSheet`. The orders load once; pull to refresh reloads them.
///
/// Professionals see it as clients; then `side` adds a `CalendarSideMenu` at
/// the top left to switch back to `CalendarScreen`.
struct ClientCalendarScreen: View {
    var side: Binding<ConfirmingParty>? = nil

    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var calendarProvider = ClientCalendarProvider()
    @State private var month = Date()
    @State private var selectedDate: Date? = nil
    @State private var slotToShow: BookedSlot? = nil
    @State private var showToast = false
    @State private var toastMessage = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var dots: [Date: [Color]] {
        calendarProvider.slotsByDay.mapValues { $0.map(\.color) }
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

                MonthCalendarView(month: $month, selectedDate: $selectedDate, dots: dots)

                if let selectedDate {
                    daySection(for: selectedDate)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .screenPadding()
        }
        .background(.brandSecondary)
        .refreshable {
            await loadOrders()
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
        .task {
            await loadOrders()
        }
        .sheet(item: $slotToShow) { slot in
            OrderDetailSheet(orderId: slot.orderId)
        }
    }

    // MARK: - Day

    @ViewBuilder
    private func daySection(for date: Date) -> some View {
        let slots = calendarProvider.slots(on: date)

        VStack(alignment: .leading, spacing: layout.internalSpacing) {
           
            if slots.isEmpty {
                Text("No tienes órdenes para este día")
                    .fatumStyle(.body)
                    .foregroundStyle(.text.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.padding)
            } else {
                // No working hours for clients: the timeline uses its default and stretches to the orders.
                DayScheduleView(date: date, slots: slots) { slot in
                    Button {
                        slotToShow = slot
                    } label: {
                        BookedSlotCard(slot: slot, title: slot.serviceTitle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Ver detalle de la orden")
                }
            }
        }
    }

    // MARK: - Load

    private func loadOrders() async {
        guard let clientId = userProvider.currentUser?.userId else { return }

        // Only errors get a toast.
        if await !calendarProvider.loadOrders(clientId: clientId) {
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
    ClientCalendarScreen()
        .environment(UserProvider())
}
