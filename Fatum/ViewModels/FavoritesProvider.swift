//
//  FavoritesProvider.swift
//  Fatum
//

import SwiftUI
import Amplify
import AWSPluginsCore

/// The signed-in user's favorite services. `MainTabView` owns one instance and
/// shares it through the environment, so Home, "Favoritos" and the service
/// page always agree on what is a favorite.
///
/// Adding and removing are optimistic: the list changes right away and goes
/// back if the request fails (`error` holds the message).
@MainActor
@Observable
final class FavoritesProvider {
    /// Mirrors the backend's `FavoriteRequest` DTO.
    private struct FavoriteRequest: Encodable {
        let clientId: String
        let serviceId: String
    }

    /// Mirrors the backend's `FavoritesByCategory` DTO, what
    /// `GET /catalog/favorites` returns without a category.
    private struct FavoritesByCategory: Decodable {
        let category: String
        let categorySlug: String
        let services: [FatumItem]
    }

    /// Every favorite, in the order the backend grouped them by category.
    var favorites: [FatumItem] = []
    var isLoading = false
    /// `true` when the last `loadFavorites` request failed; `error` holds the message.
    var loadFailed = false
    var error: String? = nil

    /// Same ALB as `CatalogProvider`.
    private let catalogBaseURL = "https://api.fatumapp.click/catalog"

    private var favoriteIds: Set<String> {
        Set(favorites.compactMap(\.id))
    }

    func isFavorite(_ item: FatumItem) -> Bool {
        item.id.map(favoriteIds.contains) ?? false
    }

    /// Favorites of one category (`FatumItem.category` is the slug); `nil` returns all of them.
    func favorites(inCategorySlug slug: String?) -> [FatumItem] {
        guard let slug else { return favorites }
        return favorites.filter { $0.category == slug }
    }

    // MARK: - Requests

    /// `GET /catalog/favorites?clientId=...`, flattening the groups by category.
    func loadFavorites(clientId: String) async {
        isLoading = true
        loadFailed = false
        error = nil
        defer { isLoading = false }

        do {
            let request = try await authorizedRequest(
                path: "/favorites",
                queryItems: [URLQueryItem(name: "clientId", value: clientId)]
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("GET", "/catalog/favorites", statusCode: statusCode, data: data)
                error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                loadFailed = true
                return
            }
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if body.isEmpty || body == "null" {
                favorites = []
                return
            }
            favorites = try JSONDecoder().decode([FavoritesByCategory].self, from: data).flatMap(\.services)
        } catch let decodingError as DecodingError {
            print("DEBUG GET /catalog/favorites decoding error: \(decodingError)")
            error = "La respuesta del servidor no tiene el formato esperado"
            loadFailed = true
        } catch {
            print("DEBUG GET /catalog/favorites error: \(error)")
            self.error = error.localizedDescription
            loadFailed = true
        }
    }

    /// `POST /catalog/favorites/add`. Returns `false` (and undoes the change) on failure.
    func add(_ item: FatumItem, clientId: String) async -> Bool {
        guard let serviceId = item.id, !isFavorite(item) else { return true }
        favorites.insert(item, at: 0)

        let success = await send(
            method: "POST",
            path: "/favorites/add",
            body: FavoriteRequest(clientId: clientId, serviceId: serviceId)
        )
        if !success {
            favorites.removeAll { $0.id == serviceId }
        }
        return success
    }

    /// `DELETE /catalog/favorites/remove/{serviceId}?clientId=...`. Returns `false` (and undoes the change) on failure.
    func remove(_ item: FatumItem, clientId: String) async -> Bool {
        guard let serviceId = item.id,
              let index = favorites.firstIndex(where: { $0.id == serviceId }) else { return true }
        let removed = favorites.remove(at: index)

        let success = await send(
            method: "DELETE",
            path: "/favorites/remove/\(serviceId)",
            queryItems: [URLQueryItem(name: "clientId", value: clientId)]
        )
        if !success {
            favorites.insert(removed, at: min(index, favorites.count))
        }
        return success
    }

    /// Sends a favorites request; `body`, when given, goes as JSON.
    private func send(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: FavoriteRequest? = nil
    ) async -> Bool {
        error = nil
        do {
            var request = try await authorizedRequest(path: path, queryItems: queryItems, method: method)
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse(method, "/catalog\(path)", statusCode: statusCode, data: data)
                error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                return false
            }
            return true
        } catch {
            print("DEBUG \(method) /catalog\(path) error: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    /// Builds a request (GET by default) for `path` under the catalog API with the Cognito token attached.
    private func authorizedRequest(path: String, queryItems: [URLQueryItem], method: String = "GET") async throws -> URLRequest {
        let idToken = try await fetchIdToken()
        var components = URLComponents(string: "\(catalogBaseURL)\(path)")!
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

    /// Prints the raw body of a failed response so the backend's exact error shows in the console.
    private static func logErrorResponse(_ method: String, _ path: String, statusCode: Int, data: Data) {
        let body = data.isEmpty ? "<empty body>" : String(data: data, encoding: .utf8) ?? "<\(data.count) bytes, not UTF-8>"
        print("DEBUG \(method) \(path) HTTP \(statusCode) response: \(body)")
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
