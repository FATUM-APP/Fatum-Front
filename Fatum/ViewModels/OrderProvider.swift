//
//  OrderProvider.swift
//  Fatum
//

import SwiftUI
import Amplify
import AWSPluginsCore

/// Loads the signed-in user's orders: `GET /order/provider` for
/// professionals and `GET /order/client` for clients. Every status is
/// requested at once and `OrdersScreen` groups them locally by `OrderFilter`.
@MainActor
@Observable
class OrderProvider {
    var orders: [FatumOrder] = []
    var isLoading = false
    /// `true` when the last `loadOrders` request failed; `error` holds the message.
    var loadFailed = false
    var error: String? = nil

    private let orderBaseURL = "https://api.fatumapp.click/order"

    /// Orders whose status belongs to `filter`.
    func orders(in filter: OrderFilter) -> [FatumOrder] {
        orders.filter { $0.orderStatus.map(filter.statuses.contains) ?? false }
    }

    /// Professionals get the orders they provide (`providerId`), clients the
    /// ones they requested (`clientId`).
    func loadOrders(userId: String, role: UserRole) async {
        isLoading = true
        loadFailed = false
        error = nil
        defer { isLoading = false }

        let path: String
        let queryItem: URLQueryItem
        switch role {
        case .professional:
            path = "/provider"
            queryItem = URLQueryItem(name: "providerId", value: userId)
        case .client:
            path = "/client"
            queryItem = URLQueryItem(name: "clientId", value: userId)
        }

        do {
            let idToken = try await fetchIdToken()
            var components = URLComponents(string: "\(orderBaseURL)\(path)")!
            components.queryItems = [queryItem]
            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
                print("DEBUG GET /order\(path) HTTP \(statusCode) response: \(body)")
                fail(Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))")
                return
            }

            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            orders = (body.isEmpty || body == "null") ? [] : try JSONDecoder().decode([FatumOrder].self, from: data)
        } catch let decodingError as DecodingError {
            print("DEBUG GET /order\(path) decoding error: \(decodingError)")
            fail("La respuesta del servidor no tiene el formato esperado")
        } catch {
            print("DEBUG GET /order\(path) error: \(error)")
            fail(error.localizedDescription)
        }
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
            let idToken = try await fetchIdToken()
            var request = URLRequest(url: URL(string: "\(orderBaseURL)/book")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
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

    private func fail(_ message: String) {
        orders = []
        loadFailed = true
        error = message
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
