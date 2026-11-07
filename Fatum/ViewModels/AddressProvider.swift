//
//  AddressProvider.swift
//  Fatum
//

import SwiftUI
import Amplify
import AWSPluginsCore

/// Owns the current user's saved addresses: loading them, knowing which one is
/// principal, and creating new ones. Screens inject it with `.environment(...)`
/// the same way they do with `UserProvider`.
@MainActor
@Observable
class AddressProvider {
    var addresses: [FatumAddress] = []
    var principalAddress: FatumAddress? = nil
    var isLoading = false
    var loadFailed = false
    var error: String? = nil

    private let userBaseURL = "https://btx2xtbb3a.execute-api.us-east-1.amazonaws.com"

    /// Request body matching the backend's `NewAddressRequest` DTO.
    /// `alias` is optional; every other field must not be blank.
    struct NewAddressRequest: Encodable {
        static let residenceMaxLength = 255
        static let aliasMaxLength = 255
        static let cityMaxLength = 50
        static let stateMaxLength = 50
        static let countryMaxLength = 50

        var residence: String
        var alias: String?
        var city: String
        var state: String
        var country: String
    }

    /// The backend's principal address when it is part of the list, otherwise the first one.
    var principal: FatumAddress? {
        if let principalAddress, addresses.contains(principalAddress) {
            return principalAddress
        }
        return addresses.first
    }

    // MARK: - Loading

    /// Loads the address list and the principal address in parallel.
    /// On failure `loadFailed` is set and `error` holds the message.
    func loadAddresses() async {
        isLoading = true
        loadFailed = false

        async let fetchedAddresses = fetchAddresses()
        async let fetchedPrincipal = fetchPrincipalAddress()
        let (list, principal) = await (fetchedAddresses, fetchedPrincipal)

        if let list {
            addresses = list
            principalAddress = principal
        } else {
            loadFailed = true
        }
        isLoading = false
    }

    /// `GET /users/addresses/mine`. Returns an empty array when the user has none,
    /// and `nil` when the request fails (`error` is set).
    private func fetchAddresses() async -> [FatumAddress]? {
        error = nil
        do {
            let request = try await authorizedRequest(path: "/users/addresses/mine", method: "GET")
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("GET", "/users/addresses/mine", statusCode: statusCode, data: data)
                self.error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                return nil
            }
            // The backend may answer with an empty body or `null` when there are no addresses.
            return (try? JSONDecoder().decode([FatumAddress].self, from: data)) ?? []
        } catch {
            print("DEBUG fetchAddresses error: \(error)")
            self.error = error.localizedDescription
            return nil
        }
    }

    /// `GET /users/addresses/principal`. Returns `nil` when there is no principal
    /// address or the request fails; the list is still usable in that case.
    private func fetchPrincipalAddress() async -> FatumAddress? {
        do {
            let request = try await authorizedRequest(path: "/users/addresses/principal", method: "GET")
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard statusCode == 200 else {
                Self.logErrorResponse("GET", "/users/addresses/principal", statusCode: statusCode, data: data)
                return nil
            }
            return try? JSONDecoder().decode(FatumAddress.self, from: data)
        } catch {
            print("DEBUG fetchPrincipalAddress error: \(error)")
            return nil
        }
    }

    // MARK: - Creating

    /// `POST /users/addresses/new`. Reloads the list on success so the screen is up to date.
    func createAddress(_ body: NewAddressRequest) async -> Bool {
        error = nil
        do {
            var request = try await authorizedRequest(path: "/users/addresses/new", method: "POST")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("POST", "/users/addresses/new", statusCode: statusCode, data: data)
                self.error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                return false
            }

            await loadAddresses()
            return true
        } catch {
            print("DEBUG createAddress error: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Updating

    /// `PUT /users/addresses/principal?alias=...`. Reloads the list on success.
    func makePrincipal(alias: String) async -> Bool {
        await sendAliasRequest(path: "/users/addresses/principal", method: "PUT", alias: alias)
    }

    /// `DELETE /users/addresses/delete?alias=...`. Reloads the list on success.
    func deleteAddress(alias: String) async -> Bool {
        await sendAliasRequest(path: "/users/addresses/delete", method: "DELETE", alias: alias)
    }

    /// Shared flow for the endpoints that identify an address by its alias query parameter.
    private func sendAliasRequest(path: String, method: String, alias: String) async -> Bool {
        error = nil
        do {
            let request = try await authorizedRequest(
                path: path,
                method: method,
                queryItems: [URLQueryItem(name: "alias", value: alias)]
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse(method, path, statusCode: statusCode, data: data)
                self.error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                return false
            }

            await loadAddresses()
            return true
        } catch {
            print("DEBUG \(method) \(path) error: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

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

    /// Builds a request for `path` under the user API with the Cognito token attached.
    /// `queryItems` are percent-encoded by `URLComponents`.
    private func authorizedRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> URLRequest {
        let idToken = try await fetchIdToken()
        var components = URLComponents(string: "\(userBaseURL)\(path)")!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
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
