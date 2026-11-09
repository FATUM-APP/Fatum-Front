//
//  CatalogProvider.swift
//  Fatum
//

import SwiftUI
import Amplify
import AWSPluginsCore

/// Owns a catalog list: the sub-categories of a root category and the services
/// of the filter the user selected ("Todas" or one sub-category). Home lists
/// every provider's services; "Mis servicios" lists only the signed-in provider's.
@MainActor
@Observable
class CatalogProvider {
    /// What the services list shows: every service under the root category,
    /// or only the ones of a single sub-category.
    enum ServiceFilter: Hashable {
        case all
        case category(FatumCategory)
    }

    /// Mirrors the backend's `CreateServiceRequest` DTO (`fatum.catalog.dto.request.item.CreateServiceRequest`).
    struct CreateServiceRequest: Encodable {
        static let providerIdMaxLength = 36
        static let titleMaxLength = 40
        static let descriptionMaxLength = 1000
        static let categoryMaxLength = 30

        let providerId: String
        let title: String
        let description: String?
        let basePrice: Decimal
        let priceType: PriceType
        let isNegotiable: Bool
        let defaultEstimatedTime: Int?
        var jobType: JobType = .PRESENCIAL
        let category: String
        let fixedQuestions: [FixedQuestion]
    }

    /// Mirrors the backend's `UpdateServiceRequest` DTO. There is no category:
    /// it can't change once the service is published.
    struct UpdateServiceRequest: Encodable {
        let id: String
        let title: String
        let description: String
        let basePrice: Decimal
        let priceType: PriceType
        let isNegotiable: Bool
        let defaultEstimatedTime: Int?
        var jobType: JobType = .PRESENCIAL
        let fixedQuestions: [FixedQuestion]
    }

    var categories: [FatumCategory] = []
    var selectedFilter: ServiceFilter? = nil
    var services: [FatumItem] = []
    var isLoadingCategories = false
    /// `true` when the last `loadCategories` request failed; `error` holds the message.
    var categoriesLoadFailed = false
    var isLoadingServices = false
    /// URL of the first photo of each service, keyed by item id. Filled after the
    /// services load; a service without an entry shows a placeholder.
    var coverImageURLs: [String: String] = [:]
    var error: String? = nil

    /// Root category whose sub-categories are listed and whose services "Todas" shows.
    let root: String

    private let catalogBaseURL = "https://btx2xtbb3a.execute-api.us-east-1.amazonaws.com/catalog"
    /// ALB endpoint (plain HTTP, port 80) tried for item creation; allowed by the ATS
    /// exception in Info.plist. Not in use right now: `createItem` goes through API Gateway.
    private let catalogUploadBaseURL = "http://fatum-alb-377854245.us-east-1.elb.amazonaws.com/catalog"

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

        await loadCoverImages(for: fetched)
    }

    // MARK: - Provider Services

    /// Selects `filter` and loads the services of one provider with
    /// `GET /catalog/item/provider?providerId=...&category=...`. `.all` leaves out
    /// `category`, so every service of the provider comes back. Cover photos load afterwards.
    func selectProviderFilter(_ filter: ServiceFilter, providerId: String) async {
        selectedFilter = filter
        services = []
        isLoadingServices = true

        var queryItems = [URLQueryItem(name: "providerId", value: providerId)]
        if case .category(let category) = filter {
            queryItems.append(URLQueryItem(name: "category", value: category.name))
        }

        let fetched = await fetchList(FatumItem.self, path: "/item/provider", queryItems: queryItems) ?? []

        // Ignore a late response if the user picked another filter meanwhile.
        guard selectedFilter == filter else { return }
        services = fetched
        isLoadingServices = false

        await loadCoverImages(for: fetched)
    }

    /// Fetches the photos of every service that has no cover yet, in parallel,
    /// and keeps the first one of each in `coverImageURLs`.
    private func loadCoverImages(for items: [FatumItem]) async {
        let ids = items.compactMap(\.id).filter { coverImageURLs[$0] == nil }
        await withTaskGroup(of: (String, String?).self) { group in
            for id in ids {
                group.addTask { (id, await self.fetchCoverImageURL(itemId: id)) }
            }
            for await (id, url) in group {
                if let url { coverImageURLs[id] = url }
            }
        }
    }

    /// `GET /catalog/item/images?id=...` and returns the first photo's URL.
    /// Failures only mean the card shows a placeholder, so they don't touch `error`.
    private func fetchCoverImageURL(itemId: String) async -> String? {
        do {
            let request = try await authorizedRequest(
                path: "/item/images",
                queryItems: [URLQueryItem(name: "id", value: itemId)]
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("GET", "/catalog/item/images", statusCode: statusCode, data: data)
                return nil
            }
            return try JSONDecoder().decode([CatalogImage].self, from: data).first?.url
        } catch {
            print("DEBUG GET /catalog/item/images error: \(error)")
            return nil
        }
    }

    // MARK: - Create & Update Item

    /// `POST /catalog/item/create`.
    func createItem(_ body: CreateServiceRequest, images: [Data]) async -> Bool {
        await sendItem(body, images: images, method: "POST", path: "/item/create")
    }

    /// `PUT /catalog/item/update`. The photos sent replace the service's current ones.
    func updateItem(_ body: UpdateServiceRequest, images: [Data]) async -> Bool {
        await sendItem(body, images: images, method: "PUT", path: "/item/update")
    }

    /// Downloads every photo of a service (`GET /catalog/item/images` and then each URL),
    /// keeping their order. Photos that fail to download are left out.
    func loadImages(itemId: String) async -> [UIImage] {
        guard let request = try? await authorizedRequest(
            path: "/item/images",
            queryItems: [URLQueryItem(name: "id", value: itemId)]
        ),
              let (data, response) = try? await URLSession.shared.data(for: request),
              let statusCode = (response as? HTTPURLResponse)?.statusCode,
              (200...299).contains(statusCode),
              let catalogImages = try? JSONDecoder().decode([CatalogImage].self, from: data) else {
            print("DEBUG GET /catalog/item/images failed for item \(itemId)")
            return []
        }

        let urls = catalogImages.compactMap { URL(string: $0.url) }
        let downloaded = await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    let data = try? await URLSession.shared.data(from: url).0
                    return (index, data.flatMap(UIImage.init(data:)))
                }
            }
            var images: [Int: UIImage] = [:]
            for await (index, image) in group {
                images[index] = image
            }
            return images
        }
        return urls.indices.compactMap { downloaded[$0] }
    }

    /// Sends a `multipart/form-data` request with `@RequestPart("request")` as JSON
    /// and `@RequestPart("images")` as JPEG files.
    private func sendItem<Body: Encodable>(_ body: Body, images: [Data], method: String, path: String) async -> Bool {
        error = nil
        do {
            let idToken = try await fetchIdToken()
            let boundary = UUID().uuidString
            let url = URL(string: "\(catalogBaseURL)\(path)")!

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            let requestJSON = try JSONEncoder().encode(body)
            var multipart = Data()
            let crlf = "\r\n"

            // Part: request (JSON body)
            multipart.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            multipart.append("Content-Disposition: form-data; name=\"request\"; filename=\"request.json\"\(crlf)".data(using: .utf8)!)
            multipart.append("Content-Type: application/json\(crlf)\(crlf)".data(using: .utf8)!)
            multipart.append(requestJSON)
            multipart.append(crlf.data(using: .utf8)!)

            // Part: images (List<MultipartFile>)
            for (index, imageData) in images.enumerated() {
                multipart.append("--\(boundary)\(crlf)".data(using: .utf8)!)
                multipart.append("Content-Disposition: form-data; name=\"images\"; filename=\"image_\(index + 1).jpg\"\(crlf)".data(using: .utf8)!)
                multipart.append("Content-Type: image/jpeg\(crlf)\(crlf)".data(using: .utf8)!)
                multipart.append(imageData)
                multipart.append(crlf.data(using: .utf8)!)
            }

            multipart.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
            request.httpBody = multipart

            // Sizes of what is being uploaded, to diagnose HTTP 413 (Request Entity Too Large).
            for (index, imageData) in images.enumerated() {
                print("DEBUG \(method) /catalog\(path) image_\(index + 1).jpg: \(Self.megabytes(imageData.count))")
            }
            print("DEBUG \(method) /catalog\(path) total body: \(Self.megabytes(multipart.count))")

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse(method, "/catalog\(path)", statusCode: statusCode, data: data)
                self.error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
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

    /// "2.37 MB" for a byte count.
    private static func megabytes(_ bytes: Int) -> String {
        String(format: "%.2f MB", Double(bytes) / 1_048_576)
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
