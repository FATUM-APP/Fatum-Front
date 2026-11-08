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
    func signIn(email: String, password: String) async -> Bool {
        error = nil
        do {
            // Clear any stale session before signing in
            _ = await Amplify.Auth.signOut()

            let result = try await Amplify.Auth.signIn(
                username: email,
                password: password
            )
            guard result.isSignedIn else { return false }
            await loadCurrentUser()
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
        return tokens.idToken
    }

    /// Loads the user from the backend API using the Cognito JWT token.
    func loadCurrentUser() async {
        error = nil
        do {
            let idToken = try await fetchIdToken()

            var request = URLRequest(url: URL(string: "\(userBaseURL)/users/me")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            let httpResponse = response as! HTTPURLResponse

            guard httpResponse.statusCode == 200 else {
                Self.logErrorResponse("GET", "/users/me", statusCode: httpResponse.statusCode, data: data)
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(Self.localDateFormatter)
            currentUser = try decoder.decode(FatumUser.self, from: data)

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

    /// Request body matching the backend's `InitializeProviderAvailability` DTO.
    private struct InitializeAvailabilityRequest: Encodable {
        let providerId: String
    }

    /// Upgrades the user to `PROFESSIONAL`, initializes their availability and
    /// reloads `/users/me` so the UI reflects the new role.
    func becomeProfessional() async -> Bool {
        error = nil
        guard let userId = currentUser?.userId else { return false }
        do {
            let idToken = try await fetchIdToken()

            // 1. PUT /users/upgrade (204 No Content on success)
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

            // 2. POST /provider/availability/initialize (201 Created on success)
            var availabilityRequest = URLRequest(url: URL(string: "\(userBaseURL)/provider/availability/initialize")!)
            availabilityRequest.httpMethod = "POST"
            availabilityRequest.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            availabilityRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            availabilityRequest.httpBody = try JSONEncoder().encode(InitializeAvailabilityRequest(providerId: userId))

            let (availabilityData, availabilityResponse) = try await URLSession.shared.data(for: availabilityRequest)
            let availabilityStatus = (availabilityResponse as? HTTPURLResponse)?.statusCode ?? 0

            // The role already changed on the backend, so reload regardless of the availability result.
            await loadCurrentUser()

            guard (200...299).contains(availabilityStatus) else {
                Self.logErrorResponse("POST", "/provider/availability/initialize", statusCode: availabilityStatus, data: availabilityData)
                self.error = Self.parseErrorMessage(from: availabilityData) ?? "Error del servidor (\(availabilityStatus))"
                return false
            }
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
