//
//  RatingProvider.swift
//  Fatum
//

import SwiftUI
import Amplify
import AWSPluginsCore

/// Mirrors the backend's `RatingTarget`: who or what is rated.
enum RatingTarget: String, Encodable {
    case CLIENT
    case PROFESSIONAL
    case SERVICE
}

/// Sends ratings with `POST /rating` once an order is completed.
@MainActor
@Observable
final class RatingProvider {
    /// Mirrors the backend's `RatingRequest`. The backend keeps any extra key as
    /// a detail, so `gustos`, `disgustos` and `comentario` go at the top level;
    /// `nil` ones are left out of the JSON.
    struct RatingRequest: Encodable {
        static let commentMaxLength = 255

        let orderId: String
        let raterId: String
        let target: RatingTarget
        let targetId: String
        /// 1...5.
        let score: Int
        /// What the rater liked (score 3 or more).
        let gustos: [String]?
        /// What went wrong (score below 3).
        let disgustos: [String]?
        let comentario: String?
    }

    enum Outcome {
        case rated
        /// 409 `RATING_ALREADY_UPDATED`: there is nothing left to send.
        case alreadyRated
        case failed(String)
    }

    private let ratingURL = "https://api.fatumapp.click/rating"

    /// `POST /rating` (201 Created).
    func rate(_ body: RatingRequest) async -> Outcome {
        do {
            let idToken = try await fetchIdToken()
            var request = URLRequest(url: URL(string: ratingURL)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch statusCode {
            case 200...299:
                return .rated
            case 409:
                return .alreadyRated
            default:
                let responseBody = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
                print("DEBUG POST /rating HTTP \(statusCode) response: \(responseBody)")
                return .failed(Self.message(for: statusCode))
            }
        } catch {
            print("DEBUG POST /rating error: \(error)")
            return .failed("No se pudo enviar la calificación. Revisa tu conexión e inténtalo de nuevo")
        }
    }

    // MARK: - Helpers

    private static func message(for statusCode: Int) -> String {
        switch statusCode {
        case 400: "Revisa la calificación e inténtalo de nuevo"
        case 404: "La orden aún no está lista para calificar. Inténtalo de nuevo en unos segundos"
        default: "No se pudo enviar la calificación (\(statusCode))"
        }
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
}
