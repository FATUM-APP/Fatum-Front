//
//  CalendarProvider.swift
//  Fatum
//

import SwiftUI
import Amplify
import AWSPluginsCore

/// Loads the provider's calendar one month at a time with `GET /provider/calendar`.
/// Months already loaded stay in `days`, so going back to one shows its dots
/// right away while it reloads.
///
/// The slots only carry the order id, so `loadDetails(for:)` brings each
/// order's `GET /order/{id}` for its service title (and the detail sheet).
/// The client's calendar uses `ClientCalendarProvider` instead.
///
/// While `CalendarScreen` is open it also listens to `/realtime/calendar`: each
/// `CALENDAR_CHANGED` event reloads the month on screen (the event carries no
/// slot details), and the orders that appear stay in `highlightedOrderIds` for a moment.
@MainActor
@Observable
class CalendarProvider {
    /// Keyed by the start of each day.
    private(set) var days: [Date: CalendarDay] = [:]
    /// Full orders already loaded, by id.
    private(set) var details: [String: FatumOrderDetail] = [:]
    /// Orders whose detail is being loaded; their cards show a placeholder title.
    private(set) var loadingDetailIds: Set<String> = []
    /// Orders that just appeared through a realtime event; their cards get an accent border.
    private(set) var highlightedOrderIds: Set<String> = []
    /// The day whose orders are on screen, set by `CalendarScreen`; a realtime
    /// reload diffs its slots to find the new ones.
    var visibleDay: Date? = nil
    var isLoading = false
    var error: String? = nil

    private let calendarURL = "https://api.fatumapp.click/provider/calendar"
    private let realtimeURL = "https://api.fatumapp.click/realtime/calendar"
    private let orderProvider = OrderProvider()

    /// Only these orders show up; the backend already filters them, this is a safety net.
    static let shownStatuses: Set<OrderStatus> = [.PENDING, .ACCEPTED, .DELIVERING]

    /// The request in flight; an older one finishing late doesn't hide the spinner.
    private var currentRequest: UUID? = nil
    /// The month last asked for, i.e. the one on screen; realtime events reload it.
    private var shownMonth: (providerId: String, year: Int, month: Int)? = nil
    /// The debounced reload of a burst of events.
    private var pendingReload: Task<Void, Never>? = nil

    /// Merges a burst of events into one reload.
    private static let reloadDebounce: Duration = .milliseconds(400)
    /// How long a new order keeps its accent border.
    private static let highlightDuration: Duration = .seconds(2)

    func day(for date: Date) -> CalendarDay? {
        days[CalendarDate.calendar.startOfDay(for: date)]
    }

    /// The shown slots of `date`, earliest first.
    func slots(on date: Date) -> [BookedSlot] {
        (day(for: date)?.bookedSlots ?? [])
            .filter { $0.orderStatus.map(Self.shownStatuses.contains) ?? false }
            .sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
    }

    /// The service title of the slot's loaded detail.
    func serviceTitle(of slot: BookedSlot) -> String? {
        details[slot.orderId]?.serviceTitle
    }

    // MARK: - Load

    /// `month` goes from 1 to 12. Returns `false` when the request fails, with
    /// the message in `error`; a cancelled request (the month changed) isn't a failure.
    /// `animation` applies to the new days, e.g. so realtime changes animate.
    func loadMonth(providerId: String, year: Int, month: Int, animation: Animation? = nil) async -> Bool {
        shownMonth = (providerId, year, month)
        let requestId = UUID()
        currentRequest = requestId
        isLoading = true
        error = nil
        defer {
            if currentRequest == requestId { isLoading = false }
        }

        do {
            let request = try await authorizedRequest(queryItems: [
                URLQueryItem(name: "providerId", value: providerId),
                URLQueryItem(name: "year", value: String(year)),
                URLQueryItem(name: "month", value: String(month))
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
                print("DEBUG GET /provider/calendar HTTP \(statusCode) response: \(body)")
                throw CalendarError(message: Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))")
            }

            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fetched = (body.isEmpty || body == "null") ? [] : try JSONDecoder().decode([CalendarDay].self, from: data)
            try Task.checkCancellation()
            withAnimation(animation) {
                replaceMonth(year: year, month: month, with: fetched)
            }
            return true
        } catch let decodingError as DecodingError {
            print("DEBUG GET /provider/calendar decoding error: \(decodingError)")
            error = "La respuesta del servidor no tiene el formato esperado"
            return false
        } catch {
            if Self.isCancellation(error) { return true }
            print("DEBUG GET /provider/calendar error: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    /// Drops the month's old days, so a day without orders anymore loses its dots.
    private func replaceMonth(year: Int, month: Int, with fetched: [CalendarDay]) {
        let calendar = CalendarDate.calendar
        days = days.filter { date, _ in
            let components = calendar.dateComponents([.year, .month], from: date)
            return components.year != year || components.month != month
        }
        for day in fetched {
            guard let date = day.day else { continue }
            days[calendar.startOfDay(for: date)] = day
        }
    }

    /// Loads, all at once, the details of the slots that don't have a title yet.
    /// A failure only leaves that card without its title.
    func loadDetails(for slots: [BookedSlot]) async {
        let missing = slots
            .filter { serviceTitle(of: $0) == nil && !loadingDetailIds.contains($0.orderId) }
            .map(\.orderId)
        guard !missing.isEmpty else { return }
        loadingDetailIds.formUnion(missing)
        defer { loadingDetailIds.subtract(missing) }

        await withTaskGroup(of: (String, FatumOrderDetail?).self) { group in
            for orderId in missing {
                group.addTask {
                    do {
                        return (orderId, try await self.orderProvider.fetchDetail(id: orderId))
                    } catch {
                        print("DEBUG calendar detail \(orderId) error: \(error)")
                        return (orderId, nil)
                    }
                }
            }
            for await (orderId, detail) in group {
                if let detail { details[orderId] = detail }
            }
        }
    }

    // MARK: - Realtime

    /// Payload of the `calendar` events of `/realtime/calendar`. `start` and
    /// `end` bound schedule and unavailability changes; they're null for `ORDER_UPDATED`.
    private struct CalendarEvent: Decodable {
        let type: String
        let providerId: String
        let change: String
        let start: String?
        let end: String?
    }

    /// Listens to `/realtime/calendar` (Server-Sent Events) until the calling task
    /// is cancelled, reconnecting a few seconds after the stream ends or fails
    /// (the server closes it every 30 minutes). Run it from the screen's `.task`
    /// so it stops when the screen goes away.
    func listenForEvents(providerId: String) async {
        // A reload waiting for its debounce belongs to the screen too.
        defer {
            pendingReload?.cancel()
            pendingReload = nil
        }

        while !Task.isCancelled {
            do {
                try await streamEvents(providerId: providerId)
            } catch {
                // Leaving the screen cancels the request (`URLError.cancelled`, -999); that's not a failure.
                if Self.isCancellation(error) { return }
                // Only the code for URL errors: the error's URL carries the token.
                if let urlError = error as? URLError {
                    print("DEBUG SSE /realtime/calendar error: \(urlError.code.rawValue)")
                } else {
                    print("DEBUG SSE /realtime/calendar error: \(error.localizedDescription)")
                }
            }
            // A failed or closed stream reconnects; the reload catches up on missed events.
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            scheduleReload()
        }
    }

    /// One connection, with a fresh token each time so a renewed one is picked up.
    /// The token goes in `access_token` because the stream can't send headers in
    /// browsers, so the backend reads it from the URL.
    private func streamEvents(providerId: String) async throws {
        var components = URLComponents(string: realtimeURL)!
        components.queryItems = [
            URLQueryItem(name: "providerId", value: providerId),
            URLQueryItem(name: "access_token", value: try await fetchIdToken())
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // The connection stays open (with a heartbeat every 20 s); only give up after a long silence.
        request.timeoutInterval = 300

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            throw CalendarError(message: "SSE HTTP \(statusCode)")
        }

        // `lines` skips blank lines, and heartbeat comments (":") match neither prefix.
        // The backend sends each event's JSON in a single `data:` line, so every
        // `data:` line is dispatched with the last `event:` name.
        var eventName = "message"
        for try await line in bytes.lines {
            if line.hasPrefix("event:") {
                eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                handle(eventName: eventName, payload: payload, providerId: providerId)
                eventName = "message"
            }
        }
    }

    private func handle(eventName: String, payload: String, providerId: String) {
        // `connected` and anything else are only logged.
        guard eventName == "calendar" else {
            print("DEBUG SSE \(eventName): \(payload)")
            return
        }
        guard let data = payload.data(using: .utf8),
              let event = try? JSONDecoder().decode(CalendarEvent.self, from: data) else {
            print("DEBUG SSE calendar event not understood: \(payload)")
            return
        }
        guard event.type == "CALENDAR_CHANGED", event.providerId == providerId else {
            print("DEBUG SSE unknown calendar event: \(event.type)")
            return
        }

        // An unknown change still reloads, to be safe.
        let change = CalendarChange(rawValue: event.change)
        if change == nil {
            print("DEBUG SSE unknown calendar change: \(event.change)")
        }
        guard affectsShownMonth(change, start: event.start, end: event.end) else { return }
        scheduleReload()
    }

    /// Fast path: a schedule or unavailability change whose range falls outside
    /// the month on screen needs no request. Order changes carry no range, so they
    /// always reload, as does anything without a readable range.
    private func affectsShownMonth(_ change: CalendarChange?, start: String?, end: String?) -> Bool {
        let calendar = CalendarDate.calendar
        guard change != .ORDER_UPDATED,
              let start = start.flatMap(CalendarDate.date(from:)),
              let end = end.flatMap(CalendarDate.date(from:)),
              let shownMonth,
              let firstDay = calendar.date(from: DateComponents(year: shownMonth.year, month: shownMonth.month)),
              let monthInterval = calendar.dateInterval(of: .month, for: firstDay)
        else { return true }

        // The range covers whole days, `end`'s included.
        let rangeStart = calendar.startOfDay(for: min(start, end))
        let lastDay = calendar.startOfDay(for: max(start, end))
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        return rangeStart < monthInterval.end && rangeEnd > monthInterval.start
    }

    /// Waits `reloadDebounce` so a burst of events turns into one reload;
    /// each new event restarts the wait.
    private func scheduleReload() {
        pendingReload?.cancel()
        pendingReload = Task {
            do {
                try await Task.sleep(for: Self.reloadDebounce)
            } catch {
                return
            }
            await reloadShownMonth()
        }
    }

    /// Reloads the month on screen with `loadMonth`, the source of truth, and
    /// diffs the visible slots by order: new ones animate in and get highlighted,
    /// gone ones (rejected, cancelled…) animate out, and the rest restyle in place.
    private func reloadShownMonth() async {
        guard let shownMonth else { return }
        let before = visibleSlotIds()

        let loaded = await loadMonth(
            providerId: shownMonth.providerId,
            year: shownMonth.year,
            month: shownMonth.month,
            animation: .snappy
        )
        guard loaded, !Task.isCancelled else { return }

        let after = visibleSlotIds()
        highlightedOrderIds.subtract(before.subtracting(after))
        let inserted = after.subtracting(before)
        if !inserted.isEmpty {
            highlight(inserted)
        }
    }

    /// The selected day's orders, or the whole month's when no day is selected
    /// (so opening the day right after still shows the highlight).
    private func visibleSlotIds() -> Set<String> {
        if let visibleDay {
            return Set(slots(on: visibleDay).map(\.orderId))
        }
        guard let shownMonth else { return [] }
        let calendar = CalendarDate.calendar
        let monthDays = days.keys.filter { date in
            let components = calendar.dateComponents([.year, .month], from: date)
            return components.year == shownMonth.year && components.month == shownMonth.month
        }
        return Set(monthDays.flatMap { slots(on: $0).map(\.orderId) })
    }

    private func highlight(_ orderIds: Set<String>) {
        withAnimation(.snappy) {
            highlightedOrderIds.formUnion(orderIds)
        }
        Task {
            try? await Task.sleep(for: Self.highlightDuration)
            withAnimation(.snappy) {
                highlightedOrderIds.subtract(orderIds)
            }
        }
    }

    // MARK: - Helpers

    private struct CalendarError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// `true` for a cancelled task, whether Swift's `CancellationError` or URLSession's `URLError.cancelled`.
    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled
    }

    /// Builds a GET request for `/provider/calendar` with the Cognito token attached.
    private func authorizedRequest(queryItems: [URLQueryItem]) async throws -> URLRequest {
        let idToken = try await fetchIdToken()
        var components = URLComponents(string: calendarURL)!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Fetches the Cognito ID token from the current session.
    private func fetchIdToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard session.isSignedIn,
              let cognitoSession = session as? AuthCognitoTokensProvider else {
            throw URLError(.userAuthenticationRequired)
        }
        return try cognitoSession.getCognitoTokens().get().idToken
    }

    /// Tries to extract a human-readable error message from a JSON response body.
    private static func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        return json["message"] as? String
            ?? json["error"] as? String
            ?? String(data: data, encoding: .utf8)
    }
}
