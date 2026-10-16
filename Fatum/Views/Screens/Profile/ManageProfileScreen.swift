//
//  ManageProfileScreen.swift
//  Fatum
//

import SwiftUI

/// The `FatumUser` fields shown on the profile screen, in display order.
/// Addresses, role, gender and active flag are intentionally excluded, and birth date is shown as age.
enum UserFieldType: String, Hashable, CaseIterable {
    case name
    case username
    case email
    case phoneNumber
    case age
    case verificationStatus

    var label: String {
        switch self {
        case .name: return "Nombre"
        case .username: return "Nombre de usuario"
        case .email: return "Correo electrónico"
        case .phoneNumber: return "Número de teléfono"
        case .age: return "Edad"
        case .verificationStatus: return "Estado de verificación"
        }
    }

    /// Only username and phone number can be edited by the user.
    var isEditable: Bool {
        switch self {
        case .username, .phoneNumber:
            return true
        default:
            return false
        }
    }

    // MARK: - Edit screen content (only meaningful for editable fields)

    var icon: String {
        switch self {
        case .username: return "person"
        case .phoneNumber: return "phone"
        default: return "pencil"
        }
    }

    var description: String {
        switch self {
        case .username: return "Tu nombre de usuario será visible para otros usuarios de la plataforma."
        case .phoneNumber: return "Tu número de teléfono será utilizado para contactarte en caso de emergencia."
        default: return ""
        }
    }

    var placeholder: String {
        switch self {
        case .username: return "Ingresa tu nombre de usuario"
        case .phoneNumber: return "Ingresa tu número de teléfono"
        default: return ""
        }
    }

    /// Formats the matching property of `user` for display.
    /// Returns `fallback` when there is no user.
    func value(for user: FatumUser?, fallback: String = "") -> String {
        guard let user else { return fallback }
        switch self {
        case .name: return user.name
        case .username: return user.username
        case .email: return user.email
        case .phoneNumber: return user.phoneNumber
        case .age: return "\(user.age) años"
        case .verificationStatus: return user.verificationStatus.displayName
        }
    }
}

struct ManageProfileScreen: View {
    @Environment(Router<ProfileRoute>.self) private var router
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Profile image
    @State private var existingImageURL: String? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isLoadingImage = true
    @State private var isUploadingImage = false

    // Upload result feedback
    @State private var showToast = false
    @State private var toastMessage: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var user: FatumUser? {
        userProvider.currentUser
    }

    private var fields: [UserFieldType] {
        UserFieldType.allCases
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile picture
                ProfileImagePicker(
                    selectedImage: $selectedImage,
                    existingImageURL: existingImageURL,
                    isLoading: isLoadingImage || isUploadingImage
                )
                .padding(layout.padding)

               
                // User fields
                VStack(spacing: 0) {
                    ForEach(Array(fields.enumerated()), id: \.element) { index, field in
                        let row = UpdateUserField(
                            fieldName: field.label,
                            fieldValue: field.value(for: user, fallback: "Sin definir"),
                            showBottomBorder: index < fields.count - 1,
                            showArrow: field.isEditable
                        )

                        if field.isEditable {
                            Button {
                                router.push(.updateUser(field))
                            } label: {
                                row
                            }
                            .buttonStyle(.plain)
                        } else {
                            row
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                ToastMessageView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showToast)
        .task {
            await loadExistingProfileImage()
        }
        .onChange(of: selectedImage) { _, newImage in
            guard let newImage else { return }
            uploadProfileImage(newImage)
        }
    }

    // MARK: - Profile image

    private func loadExistingProfileImage() async {
        isLoadingImage = true
        existingImageURL = await userProvider.fetchProfileImageURL()
        isLoadingImage = false
    }

    /// Uploads the picked image right away and reports the result in a toast.
    private func uploadProfileImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        isUploadingImage = true

        Task {
            let username = userProvider.currentUser?.username ?? "profile"
            let success = await userProvider.uploadProfileImage(
                imageData: data,
                fileName: "\(username).jpeg",
                contentType: "image/jpeg"
            )
            isUploadingImage = false

            if success {
                showMessage("Foto de perfil actualizada")
            } else {
                // Drop the failed image so the previous one shows again
                selectedImage = nil
                showMessage(userProvider.error ?? "Error al subir la foto")
            }
        }
    }

    private func showMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }
}

#Preview {
    @Previewable @State var router = Router<ProfileRoute>()
    let provider = UserProvider()
    NavigationStack(path: $router.path) {
        ManageProfileScreen()
            .profileDestinations()
    }
    .environment(router)
    .environment(provider)
}
