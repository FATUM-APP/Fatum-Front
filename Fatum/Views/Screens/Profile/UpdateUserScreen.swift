//
//  UpdateUserScreen.swift
//  Fatum
//

import SwiftUI

/// Edit screen for a single editable `UserFieldType` (username or phone number).
///
/// Layout: an icon inside a circle, the field title, a short message, the text
/// field and a confirm button. The current value is read from the shared user
/// context. On success the screen dismisses; on failure the error is shown
/// inline under the text field.
struct UpdateUserScreen: View {
    let fieldType: UserFieldType

    @Environment(Router<ProfileRoute>.self) private var router
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var newValue: String = ""
    @State private var isLoading = false
    @State private var showError = false

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// The value currently stored for this field.
    private var currentValue: String {
        fieldType.value(for: userProvider.currentUser)
    }

    private var keyboardType: UIKeyboardType {
        fieldType == .phoneNumber ? .phonePad : .default
    }

    /// Mirrors the `@Size` limits on the backend DTO.
    private var maxLength: Int {
        switch fieldType {
        case .username: return UserProvider.UserUpdateRequest.usernameMaxLength
        case .phoneNumber: return UserProvider.UserUpdateRequest.phoneNumberMaxLength
        default: return .max
        }
    }

    /// Value as the backend will store it: trimmed, and lowercased for usernames.
    private var normalizedValue: String {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return fieldType == .username ? trimmed.lowercased() : trimmed
    }

    /// Disable confirm while loading, when blank, or when nothing changed.
    private var canConfirm: Bool {
        !isLoading && !normalizedValue.isEmpty && normalizedValue != currentValue
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: layout.spacingMedium) {
                    // Icon
                    Circle()
                        .fill(Color.primaryContainer)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: fieldType.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .foregroundStyle(.brandPrimary)
                        )

                    // Title
                    Text(fieldType.label)
                        .fatumStyle(.header)
                        .foregroundStyle(.text)
                        .frame(maxWidth: .infinity)

                    // Message
                    Text(fieldType.description)
                        .fatumStyle(.body)
                        .foregroundStyle(.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    // Field
                    FatumTextField(
                        placeholder: fieldType.placeholder,
                        text: $newValue,
                        style: .standard,
                        keyboardType: keyboardType,
                        maxLength: maxLength,
                        errorMessage: showError ? (userProvider.error ?? "Error al actualizar el campo") : nil
                    )
                }
                .screenPadding()
            }

            // Confirm button
            Button {
                confirm()
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.brandSecondary)
                } else {
                    Text("Confirmar")
                }
            }
            .buttonStyle(.fatumButton(variant: .third))
            .disabled(!canConfirm)
            .screenPadding([.horizontal, .bottom])
        }
        .background(.brandSecondary)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.text)
                }
            }
        }
        .onAppear {
            newValue = currentValue
        }
        .onChange(of: newValue) { _, _ in
            showError = false
        }
    }

    // MARK: - Actions

    private func confirm() {
        isLoading = true
        Task {
            let success = await update(with: normalizedValue)
            isLoading = false
            if success {
                router.pop()
            } else {
                showError = true
            }
        }
    }

    /// Builds the request body for this field and sends it.
    private func update(with value: String) async -> Bool {
        var body = UserProvider.UserUpdateRequest()
        switch fieldType {
        case .username: body.username = value
        case .phoneNumber: body.phoneNumber = value
        default: return false
        }
        return await userProvider.updateUser(body)
    }
}

#Preview {
    let provider = UserProvider()
    NavigationStack {
        UpdateUserScreen(fieldType: .username)
    }
    .environment(Router<ProfileRoute>())
    .environment(provider)
}
