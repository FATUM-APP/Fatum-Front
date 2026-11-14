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
@MainActor
@Observable
class CalendarProvider {
    /// Keyed by the start of each day.
    private(set) var days: [Date: CalendarDay] = [:]
    /// Full orders already loaded, by id.
    private(set) var details: [String: FatumOrderDetail] = [:]
    /// Orders whose detail is being loaded; their cards show a placeholder title.
    private(set) var loadingDetailIds: Set<String> = []
    var isLoading = false
    var error: String? = nil

    private let calendarURL = "https://api.fatumapp.click/provider/calendar"
    private let orderProvider = OrderProvider()

    /// Only these orders show up; the backend already filters them, this is a safety net.
    static let shownStatuses: Set<OrderStatus> = [.PENDING, .ACCEPTED, .DELIVERING]

    /// The request in flight; an older one finishing late doesn't hide the spinner.
    private var currentRequest: UUID? = nil

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
    func loadMonth(providerId: String, year: Int, month: Int) async -> Bool {
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
            replaceMonth(year: year, month: month, with: fetched)
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
