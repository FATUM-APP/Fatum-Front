import Foundation

/// Mirrors the backend's `UserResponse` record.
struct FatumUser: Codable, Equatable {
    let userId: String
    let email: String
    var name: String
    let birthDate: Date
    var username: String
    var phoneNumber: String
    var role: UserRole
    var verificationStatus: VerificationStatus
    var isActive: Bool
    var document: String
    var gender: Gender
    var documentType: DocumentType
    var addresses: [FatumAddress]

    enum CodingKeys: String, CodingKey {
        case userId, email, name, birthDate, username, phoneNumber, role
        case verificationStatus, isActive, document, gender, documentType, addresses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        birthDate = try container.decode(Date.self, forKey: .birthDate)
        username = try container.decode(String.self, forKey: .username)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        role = try container.decode(UserRole.self, forKey: .role)
        verificationStatus = try container.decode(VerificationStatus.self, forKey: .verificationStatus)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        document = try container.decode(String.self, forKey: .document)
        gender = try container.decode(Gender.self, forKey: .gender)
        documentType = try container.decode(DocumentType.self, forKey: .documentType)
        // The backend may send `null` instead of an empty array when the user has no addresses.
        addresses = try container.decodeIfPresent([FatumAddress].self, forKey: .addresses) ?? []
    }

    // MARK: - Derived convenience values

    /// The user is considered authenticated once the backend marks them as verified.
    var isAuthenticated: Bool {
        verificationStatus == .VERIFIED
    }

    /// Age in full years, computed from `birthDate` against today's date.
    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0
    }
}
