//
//  CatalogProvider.swift
//  Fatum
//

import SwiftUI
import Amplify
import AWSPluginsCore

/// Owns the catalog shown on Home: the sub-categories of a root category and
/// the services of the filter the user selected ("Todas" or one sub-category).
@MainActor
@Observable
class CatalogProvider {
    /// What the services list shows: every service under the root category,
    /// or only the ones of a single sub-category.
    enum ServiceFilter: Hashable {
        case all
        case category(FatumCategory)
    }

    var categories: [FatumCategory] = []
    var selectedFilter: ServiceFilter? = nil
    var services: [FatumItem] = []
    var isLoadingCategories = false
    /// `true` when the last `loadCategories` request failed; `error` holds the message.
    var categoriesLoadFailed = false
    var isLoadingServices = false
    var error: String? = nil

    /// Root category whose sub-categories are listed and whose services "Todas" shows.
    let root: String

    private let catalogBaseURL = "https://btx2xtbb3a.execute-api.us-east-1.amazonaws.com/catalog"

    init(root: String) {
        self.root = root
    }

    // MARK: - Categories

    /// `GET /catalog/category/subs?root=...`. On failure `categories` is emptied,
    /// `categoriesLoadFailed` is set and `error` holds the message.
    func loadCategories() async {
        isLoadingCategories = true
        categoriesLoadFailed = false
        defer { isLoadingCategories = false }

        let fetched = await fetchList(
            FatumCategory.self,
            path: "/category/subs",
            queryItems: [URLQueryItem(name: "root", value: root)]
        )
        categories = fetched ?? []
        categoriesLoadFailed = fetched == nil
    }

    // MARK: - Services

    /// Selects `filter` and loads its services with `GET /catalog/category/services?name=...`.
    /// `.all` asks for the root category, which returns every service under it.
    func selectFilter(_ filter: ServiceFilter) async {
        selectedFilter = filter
        services = []
        isLoadingServices = true

        let name: String
        switch filter {
        case .all:
            name = root
        case .category(let category):
            name = category.name
        }

        let fetched = await fetchList(
            FatumItem.self,
            path: "/category/services",
            queryItems: [URLQueryItem(name: "name", value: name)]
        ) ?? []

        // Ignore a late response if the user picked another filter meanwhile;
        // that newer request owns `services` and the loading flag.
        guard selectedFilter == filter else { return }
        services = fetched
        isLoadingServices = false
    }

    // MARK: - Helpers

    /// Performs an authorized GET and decodes the body as a list.
    /// An empty body or `null` is an empty list. Returns `nil` on a failed
    /// request or a body that doesn't match the model (`error` is set).
    private func fetchList<Element: Decodable>(
        _ type: Element.Type,
        path: String,
        queryItems: [URLQueryItem]
    ) async -> [Element]? {
        error = nil
        do {
            let request = try await authorizedRequest(path: path, queryItems: queryItems)
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("GET", "/catalog\(path)", statusCode: statusCode, data: data)
                self.error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                return nil
            }
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if body.isEmpty || body == "null" { return [] }
            return try JSONDecoder().decode([Element].self, from: data)
        } catch let decodingError as DecodingError {
            print("DEBUG GET \(path) decoding error: \(decodingError)")
            self.error = "La respuesta del servidor no tiene el formato esperado"
            return nil
        } catch {
            print("DEBUG GET \(path) error: \(error)")
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Fetches the Cognito ID token from the current session.
    private func fetchIdToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard session.isSignedIn,
              let cognitoSession = session as? AuthCognitoTokensProvider else {
            throw URLError(.userAuthenticationRequired)
        }
        let tokens = try cognitoSession.getCognitoTokens().get()
        return tokens.idToken
    }

    /// Builds a GET request for `path` under the catalog API with the Cognito token attached.
    /// `queryItems` are percent-encoded by `URLComponents` (e.g. accented category names).
    private func authorizedRequest(path: String, queryItems: [URLQueryItem]) async throws -> URLRequest {
        let idToken = try await fetchIdToken()
        var components = URLComponents(string: "\(catalogBaseURL)\(path)")!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        return request
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

// MARK: - Display helpers

extension CatalogProvider.ServiceFilter {
    /// Label shown on the chip and the grid card.
    var title: String {
        switch self {
        case .all: "Todas"
        case .category(let category): category.name
        }
    }

    var logoUrl: String? {
        switch self {
        case .all: nil
        case .category(let category): category.logoUrl
        }
    }

    /// SF Symbol shown while the logo loads or when there is none.
    var placeholderIcon: String {
        switch self {
        case .all: "sparkles"
        case .category: "square.grid.2x2"
        }
    }
}
