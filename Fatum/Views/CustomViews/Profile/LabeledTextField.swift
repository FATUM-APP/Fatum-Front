//
//  LabeledTextField.swift
//  Fatum
//

import SwiftUI

/// A small uppercase label above a `FatumTextField`, using the profile-screen
/// colour scheme (clear fill, `.border` stroke, `.text` foreground).
/// Used for forms such as the new-address and create-service screens.
struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var icon: String? = nil
    var isOptional: Bool = false
    var maxLength: Int? = nil
    /// Shows "count/maxLength" next to the label. Requires `maxLength`.
    var showsCounter: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next
    var allowedCharacters: ((String, String) -> String)? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var displayLabel: String {
        let base = label.uppercased()
        return isOptional ? "\(base) (OPCIONAL)" : base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingSmall) {
            HStack {
                Text(displayLabel)
                    .fatumStyle(.footer)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)

                if showsCounter, let maxLength {
                    Spacer()

                    Text("\(text.count)/\(maxLength)")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text.opacity(0.6))
                }
            }

            FatumTextField(
                placeholder: placeholder,
                text: $text,
                style: .standard,
                prefixIcon: icon,
                keyboardType: keyboardType,
                textContentType: textContentType,
                submitLabel: submitLabel,
                maxLength: maxLength,
                allowedCharacters: allowedCharacters
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        LabeledTextField(
            label: "Ciudad",
            placeholder: "Ej. Envigado",
            text: .constant(""),
            icon: "building.2"
        )

        LabeledTextField(
            label: "Alias",
            placeholder: "Ej. Casa de mamá",
            text: .constant(""),
            icon: "tag",
            isOptional: true
        )

        LabeledTextField(
            label: "Título",
            placeholder: "Ej. Corte y cepillado profesional",
            text: .constant("Corte"),
            icon: "textformat",
            maxLength: 40,
            showsCounter: true
        )
    }
    .padding(20)
    .background(.brandSecondary)
}
