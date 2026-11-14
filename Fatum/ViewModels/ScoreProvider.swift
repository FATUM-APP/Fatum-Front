//
//  ScoreProvider.swift
//  Fatum
//

import SwiftUI
import Amplify
import AWSPluginsCore

/// Average ratings of users and services from the score API. `MainTabView`
/// owns one instance and shares it through the environment, so every card
/// reuses what was already fetched.
///
/// Failures only log to the console: a missing score keeps its placeholder.
@MainActor
@Observable
final class ScoreProvider {
    /// The part of the backend's `UserScoreResponse` / `ServiceScoreResponse` DTOs the app shows.
    private struct ScoreResponse: Decodable {
        let average: Double

        enum CodingKeys: String, CodingKey {
            case average
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // `BigDecimal` may come as a number or a string, or be `null` with no ratings yet.
            if let number = try? container.decodeIfPresent(Double.self, forKey: .average) {
                average = number
            } else if let text = try? container.decodeIfPresent(String.self, forKey: .average) {
                average = Double(text) ?? 0
            } else {
                average = 0
            }
        }
    }

    /// Average by userId.
    private(set) var userAverages: [String: Double] = [:]
    /// Average by serviceId.
    private(set) var serviceAverages: [String: Double] = [:]

    /// Same ALB as `CatalogProvider`.
    private let scoreBaseURL = "https://api.fatumapp.click/score"

    /// Service ids with a request in flight, so cards appearing together don't repeat it.
    private var loadingServiceIds: Set<String> = []

    // MARK: - Requests

    /// `GET /score/user?userId=...`. Always refetches, so the profile shows new ratings.
    func loadUserScore(userId: String) async {
        if let average = await fetchAverage(path: "/user", query: URLQueryItem(name: "userId", value: userId)) {
            userAverages[userId] = average
        }
    }

    /// `GET /score/service?serviceId=...`, skipped when the score is already
    /// known unless `refresh` is `true` (the service page always wants the latest).
    func loadServiceScore(serviceId: String, refresh: Bool = false) async {
        guard refresh || serviceAverages[serviceId] == nil, !loadingServiceIds.contains(serviceId) else { return }
        loadingServiceIds.insert(serviceId)
        defer { loadingServiceIds.remove(serviceId) }

        if let average = await fetchAverage(path: "/service", query: URLQueryItem(name: "serviceId", value: serviceId)) {
            serviceAverages[serviceId] = average
        }
    }

    /// Returns the response's `average`, or `nil` on failure.
    private func fetchAverage(path: String, query: URLQueryItem) async -> Double? {
        do {
            let request = try await authorizedRequest(path: path, queryItems: [query])
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("GET", "/score\(path)", statusCode: statusCode, data: data)
                return nil
            }
            return try JSONDecoder().decode(ScoreResponse.self, from: data).average
        } catch {
            print("DEBUG GET /score\(path) error: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    /// Builds a GET request for `path` under the score API with the Cognito token attached.
    private func authorizedRequest(path: String, queryItems: [URLQueryItem]) async throws -> URLRequest {
        let idToken = try await fetchIdToken()
        var components = URLComponents(string: "\(scoreBaseURL)\(path)")!
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

    /// Prints the raw body of a failed response so the backend's exact error shows in the console.
    private static func logErrorResponse(_ method: String, _ path: String, statusCode: Int, data: Data) {
        let body = data.isEmpty ? "<empty body>" : String(data: data, encoding: .utf8) ?? "<\(data.count) bytes, not UTF-8>"
        print("DEBUG \(method) \(path) HTTP \(statusCode) response: \(body)")
    }
}
