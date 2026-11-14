//
//  OrderProvider.swift
//  Fatum
//

import SwiftUI
import Amplify
import AWSPluginsCore

/// Loads the signed-in user's orders from one side: `GET /order/provider` for
/// the ones they provide and `GET /order/client` for the ones they hired.
/// Every status is requested at once and `OrdersScreen` groups them locally by `OrderFilter`.
///
/// It also sends the order actions (respond, cancel, confirm and deny each
/// stage) and listens to `/realtime/orders` while `OrdersScreen` is open.
/// Events update the card right away and then the order reloads with
/// `GET /order/{id}`, which stays the source of truth.
@MainActor
@Observable
class OrderProvider {
    var orders: [FatumOrder] = []
    var isLoading = false
    /// `true` when the last `loadOrders` request failed; `error` holds the message.
    var loadFailed = false
    var error: String? = nil
    /// Orders with an action in flight; their buttons don't run again until it finishes.
    var busyOrderIds: Set<String> = []

    private let orderBaseURL = "https://api.fatumapp.click/order"
    private let realtimeURL = "https://api.fatumapp.click/realtime/orders"

    /// Who the list was loaded for, so events and actions can reload it.
    private var userId: String? = nil
    /// The side the user takes in the listed orders; also the `party` of their confirmations.
    private(set) var party: ConfirmingParty = .CUSTOMER
    /// Orders announced by `ORDER_CREATED`, newest first; they stay at the top of the list.
    private var pinnedOrderIds: [String] = []

    /// Orders whose status belongs to `filter`.
    func orders(in filter: OrderFilter) -> [FatumOrder] {
        orders.filter { $0.orderStatus.map(filter.statuses.contains) ?? false }
    }

    // MARK: - Load

    /// `.PROVIDER` loads the orders the user provides (`providerId`), `.CUSTOMER`
    /// the ones they hired (`clientId`).
    func loadOrders(userId: String, side: ConfirmingParty) async {
        self.userId = userId
        party = side
        isLoading = true
        loadFailed = false
        error = nil
        defer { isLoading = false }

        do {
            orders = try await fetchOrders(userId: userId, side: side)
        } catch let decodingError as DecodingError {
            print("DEBUG GET /order decoding error: \(decodingError)")
            fail("La respuesta del servidor no tiene el formato esperado")
        } catch {
            print("DEBUG GET /order error: \(error)")
            fail(error.localizedDescription)
        }
    }

    /// Reloads without the spinner, after an action or an event. A failure
    /// keeps the current list instead of showing the error state.
    func refresh() async {
        guard let userId else { return }
        do {
            orders = try await fetchOrders(userId: userId, side: party)
        } catch {
            guard !Self.isCancellation(error) else { return }
            print("DEBUG refresh orders error: \(error)")
        }
    }

    /// Reloads one order with `GET /order/{id}` and replaces its card, or adds
    /// it at the top when it's new. Orders of the other side are ignored.
    /// Falls back to reloading the whole list if the request fails.
    func reloadOrder(id orderId: String) async {
        guard let userId else { return }
        do {
            let detail = try await fetchDetail(id: orderId)

            let belongsToSide = party == .PROVIDER ? detail.providerId == userId : detail.clientId == userId
            guard belongsToSide else { return }

            let order = FatumOrder(detail: detail, side: party)
            if let index = orders.firstIndex(where: { $0.id == orderId }) {
                orders[index] = order
            } else {
                orders.insert(order, at: 0)
            }
        } catch {
            guard !Self.isCancellation(error) else { return }
            print("DEBUG reload order \(orderId) error: \(error)")
            await refresh()
        }
    }

    /// `GET /order/{id}`: the full order, e.g. for `OrderDetailSheet` or the calendar's cards.
    func fetchDetail(id orderId: String) async throws -> FatumOrderDetail {
        let request = try await authorizedRequest(path: "/\(orderId)", queryItems: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
            print("DEBUG GET /order/\(orderId) HTTP \(statusCode) response: \(body)")
            throw OrderError(message: Self.parseErrorMessage(from: data).flatMap { $0.isEmpty ? nil : $0 } ?? "Error del servidor (\(statusCode))")
        }
        return try JSONDecoder().decode(FatumOrderDetail.self, from: data)
    }

    /// `GET /order/client?status=`: the client's orders in one status, without
    /// touching `orders`. Used by the client's calendar.
    func fetchClientOrders(clientId: String, status: OrderStatus) async throws -> [FatumOrder] {
        let request = try await authorizedRequest(path: "/client", queryItems: [
            URLQueryItem(name: "clientId", value: clientId),
            URLQueryItem(name: "status", value: status.rawValue)
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
            print("DEBUG GET /order/client?status=\(status.rawValue) HTTP \(statusCode) response: \(body)")
            throw OrderError(message: Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))")
        }
        let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (body.isEmpty || body == "null") ? [] : try JSONDecoder().decode([FatumOrder].self, from: data)
    }

    private func fetchOrders(userId: String, side: ConfirmingParty) async throws -> [FatumOrder] {
        let path: String
        let queryItem: URLQueryItem
        switch side {
        case .PROVIDER:
            path = "/provider"
            queryItem = URLQueryItem(name: "providerId", value: userId)
        case .CUSTOMER:
            path = "/client"
            queryItem = URLQueryItem(name: "clientId", value: userId)
        }

        let request = try await authorizedRequest(path: path, queryItems: [queryItem])
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
            print("DEBUG GET /order\(path) HTTP \(statusCode) response: \(body)")
            throw OrderError(message: Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))")
        }

        let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fetched = (body.isEmpty || body == "null") ? [] : try JSONDecoder().decode([FatumOrder].self, from: data)
        return pinningNewOrders(fetched)
    }

    /// Moves the orders from `ORDER_CREATED` to the top, newest first.
    private func pinningNewOrders(_ fetched: [FatumOrder]) -> [FatumOrder] {
        let pinned = pinnedOrderIds.compactMap { id in fetched.first { $0.id == id } }
        let rest = fetched.filter { order in !pinnedOrderIds.contains { $0 == order.id } }
        return pinned + rest
    }

    private func fail(_ message: String) {
        orders = []
        loadFailed = true
        error = message
    }

    // MARK: - Actions

    /// Mirrors the backend's `OrderResponse` (`PUT /order/respond`).
    private struct RespondRequest: Encodable {
        let orderId: String
        let providerId: String
        let status: OrderStatus
        let estimatedTime: Int?
        let reason: String?
    }

    /// Mirrors the backend's `UpdateReason`.
    private struct ReasonBody: Encodable {
        let reason: String
    }

    /// Limit of `OrderResponse.reason`; used for every reason the app sends.
    static let reasonMaxLength = 500

    /// `PUT /order/respond` with `ACCEPTED` and the provider's estimated time in minutes.
    func accept(_ order: FatumOrder, estimatedTime: Int) async -> Bool {
        await respond(to: order, status: .ACCEPTED, estimatedTime: estimatedTime, reason: nil)
    }

    /// `PUT /order/respond` with `REJECTED` and the reason; no estimated time.
    func reject(_ order: FatumOrder, reason: String) async -> Bool {
        await respond(to: order, status: .REJECTED, estimatedTime: nil, reason: reason)
    }

    /// Only the provider responds, so `providerId` is the signed-in user.
    private func respond(to order: FatumOrder, status: OrderStatus, estimatedTime: Int?, reason: String?) async -> Bool {
        guard let orderId = order.id, let userId else { return false }
        let body = RespondRequest(
            orderId: orderId,
            providerId: userId,
            status: status,
            estimatedTime: estimatedTime,
            reason: reason
        )
        return await perform(orderId: orderId, path: "/respond", body: body)
    }

    /// `PUT /order/cancel/{orderId}`. `reason` already carries the "CLIENT: " /
    /// "PROFESSIONAL: " prefix.
    func cancel(_ order: FatumOrder, reason: String) async -> Bool {
        guard let orderId = order.id else { return false }
        return await perform(orderId: orderId, path: "/cancel/\(orderId)", body: ReasonBody(reason: reason))
    }

    /// `PUT /order/confirm/{stage}/{orderId}?party=...`.
    func confirm(_ stage: OrderStage, for order: FatumOrder) async -> Bool {
        guard let orderId = order.id else { return false }
        return await perform(
            orderId: orderId,
            path: "/confirm/\(stage.path)/\(orderId)",
            queryItems: [URLQueryItem(name: "party", value: party.rawValue)],
            body: Optional<ReasonBody>.none
        )
    }

    /// `PUT /order/deny/{stage}/{orderId}?party=...` with the reason.
    func deny(_ stage: OrderStage, for order: FatumOrder, reason: String) async -> Bool {
        guard let orderId = order.id else { return false }
        return await perform(
            orderId: orderId,
            path: "/deny/\(stage.path)/\(orderId)",
            queryItems: [URLQueryItem(name: "party", value: party.rawValue)],
            body: ReasonBody(reason: reason)
        )
    }

    /// Sends a `PUT`, marks the order busy meanwhile and reloads the order on
    /// success. On failure `error` holds the message.
    private func perform<Body: Encodable>(
        orderId: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Body?
    ) async -> Bool {
        guard !busyOrderIds.contains(orderId) else { return false }
        busyOrderIds.insert(orderId)
        defer { busyOrderIds.remove(orderId) }
        error = nil

        do {
            var request = try await authorizedRequest(path: path, queryItems: queryItems, method: "PUT")
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                let responseBody = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
                print("DEBUG PUT /order\(path) HTTP \(statusCode) response: \(responseBody)")
                let message = Self.parseErrorMessage(from: data).flatMap { $0.isEmpty ? nil : $0 }
                error = message ?? "No se pudo actualizar la orden (\(statusCode))"
                return false
            }
        } catch {
            print("DEBUG PUT /order\(path) error: \(error)")
            self.error = error.localizedDescription
            return false
        }

        await reloadOrder(id: orderId)
        return true
    }

    // MARK: - Book

    /// Mirrors the backend's `QuestionAnswer`: a fixed question and the chosen
    /// options, or a single element with the typed text.
    struct QuestionAnswer: Encodable, Hashable {
        let question: String
        let answer: Set<String>
    }

    /// Mirrors the backend's `BookService` DTO. `nil` fields are left out of the JSON.
    struct BookServiceRequest: Encodable {
        static let requirementsMaxLength = 500

        let clientId: String
        /// `LocalDateTime`, e.g. "2026-11-25T14:30:00".
        let booking: String
        let serviceId: String
        /// Only for negotiable services; the backend uses the base price otherwise.
        let negotiatedPrice: Decimal?
        let answers: [QuestionAnswer]
        let requirements: String?

        /// Formats `date` as a `LocalDateTime` in the device's time zone.
        static func localDateTime(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            return formatter.string(from: date)
        }
    }

    /// `POST /order/book` (201 Created). On failure `error` holds the message.
    func book(_ body: BookServiceRequest) async -> Bool {
        error = nil
        do {
            var request = try await authorizedRequest(path: "/book", queryItems: [], method: "POST")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                let responseBody = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
                print("DEBUG POST /order/book HTTP \(statusCode) response: \(responseBody)")
                // An empty body would otherwise become an empty message.
                let message = Self.parseErrorMessage(from: data).flatMap { $0.isEmpty ? nil : $0 }
                error = message ?? "No se pudo contratar el servicio (\(statusCode))"
                return false
            }
            return true
        } catch {
            print("DEBUG POST /order/book error: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Availability

    /// Mirrors the backend's `AvailabilityResponse`; only `available` is used.
    /// `reason` is the `AvailabilityReason` (`LEAD_TIME`, `UNAVAILABLE_RANGE`, `OVERLAP`,
    /// `OUT_OF_SCHEDULE`), kept as a `String` so a new case doesn't break decoding.
    struct AvailabilityResponse: Decodable {
        let available: Bool
        let reason: String?
    }

    /// `GET /order/availability`. Returns `nil` when the check fails, so the
    /// caller can treat the slot as unknown instead of unavailable.
    func checkAvailability(providerId: String, booking: Date, durationMinutes: Int?) async -> AvailabilityResponse? {
        var queryItems = [
            URLQueryItem(name: "providerId", value: providerId),
            URLQueryItem(name: "booking", value: BookServiceRequest.localDateTime(booking))
        ]
        if let durationMinutes {
            queryItems.append(URLQueryItem(name: "durationMinutes", value: String(durationMinutes)))
        }

        do {
            let request = try await authorizedRequest(path: "/availability", queryItems: queryItems)
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
                print("DEBUG GET /order/availability HTTP \(statusCode) response: \(body)")
                return nil
            }
            return try JSONDecoder().decode(AvailabilityResponse.self, from: data)
        } catch {
            guard !Self.isCancellation(error) else { return nil }
            print("DEBUG GET /order/availability error: \(error)")
            return nil
        }
    }

    // MARK: - Realtime

    /// Payload of the `order` events of `/realtime/orders`. Only `type` is common
    /// to every event; the rest depends on it.
    private struct OrderEvent: Decodable {
        let type: String
        let orderId: String?
        let status: String?
        let reason: String?
        let confirmation: String?
        let party: String?
        let confirmed: Bool?
    }

    /// Listens to `/realtime/orders` (Server-Sent Events) until the calling task
    /// is cancelled, reconnecting a few seconds after the stream ends or fails.
    /// Run it from the screen's `.task` so it stops when the screen goes away.
    func listenForEvents() async {
        while !Task.isCancelled {
            do {
                try await streamEvents()
            } catch {
                // Leaving the screen cancels the request (`URLError.cancelled`, -999); that's not a failure.
                if Self.isCancellation(error) { return }
                // Only the code: the error's URL carries the token.
                print("DEBUG SSE /realtime/orders error: \((error as? URLError)?.code.rawValue ?? 0) \(error.localizedDescription)")
            }
            // A failed or closed stream reconnects; the reload catches up on missed events.
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            await refresh()
        }
    }

    /// `true` for a cancelled task, whether Swift's `CancellationError` or URLSession's `URLError.cancelled`.
    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled
    }

    /// One connection. The token goes in `access_token` because the stream
    /// can't send headers in browsers, so the backend reads it from the URL.
    private func streamEvents() async throws {
        var components = URLComponents(string: realtimeURL)!
        components.queryItems = [URLQueryItem(name: "access_token", value: try await fetchIdToken())]
        var request = URLRequest(url: components.url!)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // The connection stays open; only give up after a long silence.
        request.timeoutInterval = 300

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            throw OrderError(message: "SSE HTTP \(statusCode)")
        }

        // `lines` skips blank lines, so an event can't be closed by its empty
        // separator line. The backend sends each event's JSON in a single
        // `data:` line, so every `data:` line is dispatched with the last `event:` name.
        var eventName = "message"
        for try await line in bytes.lines {
            if line.hasPrefix("event:") {
                eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                await handle(eventName: eventName, payload: payload)
                eventName = "message"
            }
        }
    }

    private func handle(eventName: String, payload: String) async {
        guard eventName == "order" else {
            print("DEBUG SSE \(eventName): \(payload)")
            return
        }
        guard let data = payload.data(using: .utf8),
              let event = try? JSONDecoder().decode(OrderEvent.self, from: data) else {
            print("DEBUG SSE order event not understood: \(payload)")
            return
        }

        apply(event)
        if let orderId = event.orderId {
            await reloadOrder(id: orderId)
        } else {
            await refresh()
        }
    }

    /// Updates the card right away, before the reload confirms it.
    private func apply(_ event: OrderEvent) {
        switch event.type {
        case "ORDER_CREATED":
            // The reload adds the card; pinning keeps it at the top after full reloads too.
            if let orderId = event.orderId {
                pinnedOrderIds.removeAll { $0 == orderId }
                pinnedOrderIds.insert(orderId, at: 0)
            }
        case "ORDER_STATUS_CHANGED":
            guard let index = index(of: event.orderId), let status = event.status else { return }
            orders[index].status = status
            orders[index].reason = event.reason
        case "ORDER_CONFIRMATION_CHANGED":
            guard let index = index(of: event.orderId),
                  let stage = event.confirmation.flatMap(OrderStage.init(rawValue:)),
                  let party = event.party.flatMap(ConfirmingParty.init(rawValue:)),
                  let confirmed = event.confirmed else { return }
            orders[index].setAnswer(confirmed, of: party, for: stage)
        default:
            print("DEBUG SSE unknown order event: \(event.type)")
        }
    }

    private func index(of orderId: String?) -> Int? {
        guard let orderId else { return nil }
        return orders.firstIndex { $0.id == orderId }
    }

    // MARK: - Helpers

    private struct OrderError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Builds a request (GET by default) for `path` under `/order` with the Cognito token attached.
    private func authorizedRequest(path: String, queryItems: [URLQueryItem], method: String = "GET") async throws -> URLRequest {
        let idToken = try await fetchIdToken()
        var components = URLComponents(string: "\(orderBaseURL)\(path)")!
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
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
