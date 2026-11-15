import SwiftUI
import Amplify
import AWSPluginsCore

@MainActor
@Observable
class UserProvider {
    var currentUser: FatumUser? = nil
    var error: String? = nil
    var isCheckingSession = true

    private let userBaseURL = "https://btx2xtbb3a.execute-api.us-east-1.amazonaws.com"

    var isLoggedIn: Bool { currentUser != nil }

    func clearUser() {
        currentUser = nil
        error = nil
    }

    /// Signs in with Cognito and loads the user profile.
    ///
    /// `isNewAccount` is for the first sign-in right after confirming the
    /// sign-up: the backend finishes setting up the account on that first
    /// `/users/me`, after the token was issued, so the token is refreshed before
    /// `currentUser` is set (which opens Home and starts its requests).
    func signIn(email: String, password: String, isNewAccount: Bool = false) async -> Bool {
        error = nil
        do {
            // Clear any stale session before signing in
            _ = await Amplify.Auth.signOut()

            let result = try await Amplify.Auth.signIn(
                username: email,
                password: password
            )
            guard result.isSignedIn else { return false }
            if isNewAccount {
                let user = try await fetchCurrentUser()
                // The Lambda adds VERIFIED after the event, not before the sign-in, so the
                // token from the sign-in does not carry the group yet.
                _ = await waitForGroup("VERIFIED")
                currentUser = user
                isCheckingSession = false
            } else {
                await loadCurrentUser()
            }
            return isLoggedIn
        } catch let authError as AuthError {
            error = authError.errorDescription
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Signs out the current user.
    func signOut() async {
        _ = await Amplify.Auth.signOut()
        clearUser()
    }

    // MARK: - Sign up

    /// Everything the register form collects. Mapped to Cognito attributes
    /// here so views never deal with `AuthUserAttribute`.
    struct SignUpRequest {
        var name: String
        var phone: String
        var gender: Gender
        var email: String
        var username: String
        var password: String
        var birthday: Date
        var document: String
        var documentType: DocumentType
    }

    enum SignUpOutcome {
        /// Cognito sent a code; the caller must show `ConfirmationView`.
        case needsConfirmation
        /// The account is ready; the caller can sign in right away.
        case completed
    }

    /// Creates the Cognito account. Returns `nil` on failure with `error` set.
    func signUp(_ request: SignUpRequest) async -> SignUpOutcome? {
        error = nil
        let attributes: [AuthUserAttribute] = [
            .init(.email, value: request.email),
            .init(.name, value: request.name),
            .init(.phoneNumber, value: "+57\(request.phone)"),
            .init(.birthDate, value: Self.localDateFormatter.string(from: request.birthday)),
            .init(.gender, value: request.gender.rawValue),
            .init(.custom("username"), value: request.username),
            .init(.custom("document"), value: request.document),
            .init(.custom("documentType"), value: request.documentType.rawValue),
        ]
        do {
            let result = try await Amplify.Auth.signUp(
                username: request.email,
                password: request.password,
                options: .init(userAttributes: attributes)
            )
            if case .confirmUser = result.nextStep {
                return .needsConfirmation
            }
            return .completed
        } catch let authError as AuthError {
            error = authError.errorDescription
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Confirms the e-mail with the code Cognito sent. Returns `true` when the sign-up is complete.
    func confirmSignUp(email: String, code: String) async -> Bool {
        error = nil
        do {
            let result = try await Amplify.Auth.confirmSignUp(for: email, confirmationCode: code)
            return result.isSignUpComplete
        } catch let authError as AuthError {
            error = authError.errorDescription
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Asks Cognito to send a new confirmation code.
    func resendSignUpCode(email: String) async -> Bool {
        error = nil
        do {
            _ = try await Amplify.Auth.resendSignUpCode(for: email)
            return true
        } catch let authError as AuthError {
            error = authError.errorDescription
            return false
        } catch {
            self.error = error.localizedDescription
            return false
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
        #if DEBUG
        // Every request prints the groups of the token it is about to send, so a 403 can be
        // matched against the claim without guessing.
        Self.debugGroups(tokens.idToken, label: "fetchIdToken")
        #endif
        return tokens.idToken
    }

    /// Asks Cognito for new tokens, so claims the backend changed after sign-in
    /// (e.g. the role after `/users/upgrade`) reach every service. Without it the
    /// old token stays until the user signs in again.
    private func refreshTokens() async throws {
        _ = try await Amplify.Auth.fetchAuthSession(options: .forceRefresh())
    }

    /// Refreshes until the token carries `group`, or gives up after about seven seconds.
    ///
    /// Cognito writes the groups into the token when it is issued, and the Lambda that adds
    /// them runs after the event, so the token from the sign-in does not carry them yet.
    /// Refreshing in a loop is what closes that gap without asking the user to sign in again.
    private func waitForGroup(_ group: String, attempts: Int = 10) async -> Bool {
        for attempt in 0..<attempts {
            if let token = try? await refreshedIdToken(), Self.groups(of: token).contains(group) {
                return true
            }
            if attempt < attempts - 1 {
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
        return false
    }

    /// Forces a new token and returns it, so the claims read next are the fresh ones.
    private func refreshedIdToken() async throws -> String {
        _ = try await Amplify.Auth.fetchAuthSession(options: .forceRefresh())
        return try await fetchIdToken()
    }

    /// `cognito:groups` of a token. Decoded only to read it, never trusted for a decision.
    private static func groups(of token: String) -> Set<String> {
        let parts = token.split(separator: ".")
        guard parts.count > 1 else { return [] }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = claims["cognito:groups"] as? [String] else { return [] }
        return Set(groups)
    }

    #if DEBUG
    /// Groups of a token that is already in hand.
    ///
    /// It takes the token as a parameter instead of fetching it, so calling it from
    /// `fetchIdToken` cannot recurse.
    private static func debugGroups(_ token: String, label: String) {
        let parts = token.split(separator: ".")
        guard parts.count > 1 else { return }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        print("DEBUG groups (\(label)): \(claims["cognito:groups"] ?? "SIN CLAIM") "
              + "token_use=\(claims["token_use"] ?? "?") sub=\(claims["sub"] ?? "?")")
    }
    #endif

    /// `GET /users/me`, without touching `currentUser`.
    private func fetchCurrentUser() async throws -> FatumUser {
        let idToken = try await fetchIdToken()

        var request = URLRequest(url: URL(string: "\(userBaseURL)/users/me")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard statusCode == 200 else {
            Self.logErrorResponse("GET", "/users/me", statusCode: statusCode, data: data)
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.localDateFormatter)
        return try decoder.decode(FatumUser.self, from: data)
    }

    /// Loads the user from the backend API using the Cognito JWT token.
    func loadCurrentUser() async {
        error = nil
        do {
            currentUser = try await fetchCurrentUser()
        } catch {
            print("DEBUG loadCurrentUser error: \(error)")
            self.error = error.localizedDescription
            currentUser = nil
        }
        isCheckingSession = false
    }

    /// Request body matching the backend's `UserUpdateRequest` DTO.
    ///
    /// Only set the field being changed. `nil` fields are omitted from the JSON,
    /// which the backend reads as "do not touch it".
    struct UserUpdateRequest: Encodable {
        static let usernameMaxLength = 15
        static let phoneNumberMaxLength = 20

        var username: String?
        var phoneNumber: String?
    }

    /// Sends a PUT to `/users/update` with the given body and reloads the user on success.
    func updateUser(_ body: UserUpdateRequest) async -> Bool {
        error = nil
        do {
            let idToken = try await fetchIdToken()
            var request = URLRequest(url: URL(string: "\(userBaseURL)/users/update")!)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("PUT", "/users/update", statusCode: statusCode, data: data)
                self.error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                return false
            }

            // Reload the full user profile after successful update
            await loadCurrentUser()
            return true

        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Become Professional

    /// Upgrades the user to `PROFESSIONAL` and reloads `/users/me` so the UI
    /// reflects the new role.
    func becomeProfessional() async -> Bool {
        error = nil
        guard currentUser != nil else { return false }
        do {
            let idToken = try await fetchIdToken()

            // PUT /users/upgrade (204 No Content on success)
            var upgradeRequest = URLRequest(url: URL(string: "\(userBaseURL)/users/upgrade")!)
            upgradeRequest.httpMethod = "PUT"
            upgradeRequest.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            let (upgradeData, upgradeResponse) = try await URLSession.shared.data(for: upgradeRequest)
            let upgradeStatus = (upgradeResponse as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(upgradeStatus) else {
                Self.logErrorResponse("PUT", "/users/upgrade", statusCode: upgradeStatus, data: upgradeData)
                self.error = Self.parseErrorMessage(from: upgradeData) ?? "Error del servidor (\(upgradeStatus))"
                return false
            }

            // The old token still says CLIENT, and PROFESSIONAL arrives through the Lambda.
            // Waiting for the claim is what lets the provider screens work on the first try.
            _ = await waitForGroup("PROFESSIONAL")
            await loadCurrentUser()
            return true
        } catch {
            print("DEBUG becomeProfessional error: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Profile Image

    /// Checks whether the user has a profile image.
    /// Returns the presigned download URL if found, nil if not found.
    func fetchProfileImageURL() async -> String? {
        do {
            let idToken = try await fetchIdToken()
            let urlString = "\(userBaseURL)/profile-image/"
            var request = URLRequest(url: URL(string: urlString)!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard statusCode == 200 else {
                Self.logErrorResponse("GET", "/profile-image/", statusCode: statusCode, data: data)
                return nil
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let url = json["downloadUrl"] as? String {
                return url
            }
            return nil
        } catch {
            print("DEBUG fetchProfileImageURL error: \(error)")
            return nil
        }
    }

    // MARK: - Public Profile

    /// The parts of another user's `UserResponse` shown to clients (e.g. a service's provider).
    struct PublicProfile: Decodable {
        let name: String
        let username: String
    }

    /// `GET /users/user/{userId}`, for anyone's profile, not only the signed-in user's.
    /// Returns `nil` on failure without touching `error`; the caller keeps its fallback.
    func fetchPublicProfile(userId: String) async -> PublicProfile? {
        let path = "/users/user/\(userId)"
        do {
            let (data, response) = try await URLSession.shared.data(for: authorizedGetRequest(path: path))
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard statusCode == 200 else {
                Self.logErrorResponse("GET", path, statusCode: statusCode, data: data)
                return nil
            }
            return try JSONDecoder().decode(PublicProfile.self, from: data)
        } catch {
            print("DEBUG GET \(path) error: \(error)")
            return nil
        }
    }

    /// `GET /profile-image/user/{userId}`. Returns the download URL, or `nil`
    /// when the user has no photo or the request fails.
    func fetchProfileImageURL(userId: String) async -> String? {
        let path = "/profile-image/user/\(userId)"
        do {
            let (data, response) = try await URLSession.shared.data(for: authorizedGetRequest(path: path))
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard statusCode == 200 else {
                Self.logErrorResponse("GET", path, statusCode: statusCode, data: data)
                return nil
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["downloadUrl"] as? String
        } catch {
            print("DEBUG GET \(path) error: \(error)")
            return nil
        }
    }

    /// GET for `path` with the Cognito token. These routes are meant to be public,
    /// but the backend still answers 401 without it.
    /// TODO: drop the token once `/users/user/**` and `/profile-image/user/**` are public.
    private func authorizedGetRequest(path: String) async throws -> URLRequest {
        let idToken = try await fetchIdToken()
        var request = URLRequest(url: URL(string: "\(userBaseURL)\(path)")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Uploads a profile image as multipart/form-data.
    /// Backend expects: PUT /profile-image/update with @RequestParam("image") MultipartFile
    func uploadProfileImage(imageData: Data, fileName: String, contentType: String) async -> Bool {
        error = nil
        do {
            let idToken = try await fetchIdToken()
            let boundary = UUID().uuidString
            let urlString = "\(userBaseURL)/profile-image/update"
            var request = URLRequest(url: URL(string: urlString)!)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.multipartBody(boundary: boundary, fieldName: "image", fileName: fileName, contentType: contentType, fileData: imageData)

            print("DEBUG uploadProfileImage URL: \(urlString)")
            print("DEBUG uploadProfileImage bodySize: \(request.httpBody?.count ?? 0)")

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("DEBUG uploadProfileImage HTTP \(statusCode)")

            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("PUT", "/profile-image/update", statusCode: statusCode, data: data)
                self.error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                return false
            }
            return true
        } catch {
            print("DEBUG uploadProfileImage error: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Document

    /// Uploads a single pre-scanned PDF document.
    /// Backend expects: POST /documents/upload/single with fields "type" and "file" (PDF).
    func uploadDocumentPdf(documentType: DocumentType, pdfData: Data, fileName: String) async -> Bool {
        error = nil
        do {
            let idToken = try await fetchIdToken()
            let boundary = UUID().uuidString
            let urlString = "\(userBaseURL)/documents/upload/single"
            var request = URLRequest(url: URL(string: urlString)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            let crlf = "\r\n"

            // Field: type
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"type\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("\(documentType.rawValue)\(crlf)".data(using: .utf8)!)

            // Field: file (PDF)
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
            body.append("Content-Type: application/pdf\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(pdfData)
            body.append(crlf.data(using: .utf8)!)

            body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
            request.httpBody = body

            print("DEBUG uploadDocumentPdf URL: \(urlString)")
            print("DEBUG uploadDocumentPdf type: \(documentType.rawValue), pdfSize: \(pdfData.count)")

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("DEBUG uploadDocumentPdf HTTP \(statusCode)")

            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("POST", "/documents/upload/single", statusCode: statusCode, data: data)
                self.error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                return false
            }
            return true
        } catch {
            print("DEBUG uploadDocumentPdf error: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Authentication

    /// Calls the authenticate endpoint. Returns true if the backend confirms isAuthenticated.
    func authenticateUser() async -> Bool {
        error = nil
        do {
            let idToken = try await fetchIdToken()
            var request = URLRequest(url: URL(string: "\(userBaseURL)/users/authenticate")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                Self.logErrorResponse("POST", "/users/authenticate", statusCode: statusCode, data: data)
                self.error = Self.parseErrorMessage(from: data) ?? "Error del servidor (\(statusCode))"
                return false
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isAuthenticated = json["isAuthenticated"] as? Bool {
                return isAuthenticated
            }
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Multipart Helper

    /// Builds a multipart/form-data body for a single file upload.
    private static func multipartBody(
        boundary: String,
        fieldName: String,
        fileName: String,
        contentType: String,
        fileData: Data
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(fileData)
        body.append("\(crlf)--\(boundary)--\(crlf)".data(using: .utf8)!)
        return body
    }

    // MARK: - Helpers

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

    /// DateFormatter for the backend's "yyyy-MM-dd" LocalDate format.
    private static let localDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
