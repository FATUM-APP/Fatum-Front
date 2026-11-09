//
//  FatumTextField.swift
//  Fatum
//
//  Created by Camilo Castaño on 18/04/26.
//

import SwiftUI

/// Colours shared by `FatumTextField` and `FatumPicker`.
///
/// - `.login`: screens shown before sign-in (gradient background, filled boxes).
/// - `.standard`: screens shown after sign-in (plain background, clear boxes).
struct FatumFieldStyle {
    var borderColor: Color
    var focusedBorderColor: Color
    var errorBorderColor: Color
    var fillColor: Color
    var textColor: Color
    var iconColor: Color

    static let cornerRadius: CGFloat = 12

    static let login = FatumFieldStyle(
        borderColor: .borderLogin,
        focusedBorderColor: .borderLogin,
        errorBorderColor: .errorBorderLogin,
        fillColor: .thirdGradient.opacity(0.6),
        textColor: .brandPrimary,
        iconColor: .brandPrimary
    )

    static let standard = FatumFieldStyle(
        borderColor: .border,
        focusedBorderColor: .border,
        errorBorderColor: .errorBorderLogin,
        fillColor: .clear,
        textColor: .text,
        iconColor: .text
    )
}

struct FatumTextField: View {
    let placeholder: String
    @Binding var text: String
    var style: FatumFieldStyle = .login

    // Optional configuration
    var prefixIcon: String? = nil
    /// Hides the text and shows an eye button to reveal it.
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .done
    var maxLength: Int? = nil
    var errorMessage: String? = nil
    var allowedCharacters: ((String, String) -> String)? = nil

    @FocusState private var isFocused: Bool
    @State private var isRevealed = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var hasError: Bool {
        errorMessage != nil
    }

    private var currentBorderColor: Color {
        if hasError { return style.errorBorderColor }
        if isFocused { return style.focusedBorderColor }
        return style.borderColor
    }

    private var currentBorderWidth: CGFloat {
        (isFocused || hasError) ? 2 : 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingSmall) {
            HStack(spacing: layout.internalSpacing) {
                // Prefix icon
                if let prefixIcon {
                    Image(systemName: prefixIcon)
                        .foregroundStyle(style.iconColor)
                }

                // Text field
                if isSecure && !isRevealed {
                    SecureField(placeholder, text: filteredText)
                        .focused($isFocused)
                        .textContentType(textContentType)
                        .submitLabel(submitLabel)
                } else {
                    TextField(placeholder, text: filteredText)
                        .focused($isFocused)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(submitLabel)
                }

                // Show / hide password
                if isSecure {
                    Button {
                        let wasFocused = isFocused
                        isRevealed.toggle()
                        // Swapping SecureField <-> TextField drops focus; restore it.
                        if wasFocused { isFocused = true }
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .foregroundStyle(style.iconColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isRevealed ? "Ocultar contraseña" : "Mostrar contraseña")
                }
            }
            .fatumStyle(.body)
            .foregroundStyle(style.textColor)
            .padding(layout.internalPadding)
            .background(style.fillColor)
            .clipShape(RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                    .stroke(currentBorderColor, lineWidth: currentBorderWidth)
            )

            // Error message
            if let errorMessage {
                Text(errorMessage)
                    .fatumStyle(.footer)
                    .foregroundStyle(style.errorBorderColor)
            }
        }
    }

    /// Binding that enforces character filtering and maxLength
    private var filteredText: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                var filtered = newValue
                if let allowedCharacters {
                    filtered = allowedCharacters(text, newValue)
                }
                if let maxLength, filtered.count > maxLength {
                    filtered = String(filtered.prefix(maxLength))
                }
                text = filtered
            }
        )
    }
}

#Preview("Login style") {
    VStack(spacing: 20) {
        FatumTextField(placeholder: "Correo electrónico", text: .constant(""), prefixIcon: "envelope")

        FatumTextField(placeholder: "Contraseña", text: .constant("secreto"), prefixIcon: "lock", isSecure: true)

        FatumTextField(
            placeholder: "Correo electrónico",
            text: .constant("test@"),
            prefixIcon: "envelope",
            errorMessage: "Correo electrónico no válido"
        )
    }
    .padding(20)
    .background(AppGradient.mainBackground)
}

#Preview("Standard style") {
    VStack(spacing: 20) {
        FatumTextField(placeholder: "Ingresa tu nombre de usuario", text: .constant(""), style: .standard)

        FatumTextField(placeholder: "Contraseña", text: .constant(""), style: .standard, isSecure: true)
    }
    .padding(20)
    .background(.brandSecondary)
}
