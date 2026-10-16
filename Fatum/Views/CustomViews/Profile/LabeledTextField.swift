//
//  LabeledTextField.swift
//  Fatum
//

import SwiftUI

/// A small uppercase label above a `FatumTextField`, using the profile-screen
/// colour scheme (clear fill, `.border` stroke, `.text` foreground).
/// Used for forms such as the new-address screen.
struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var icon: String? = nil
    var isOptional: Bool = false
    var maxLength: Int? = nil
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next

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
            Text(displayLabel)
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.text)

            FatumTextField(
                placeholder: placeholder,
                text: $text,
                style: .standard,
                prefixIcon: icon,
                textContentType: textContentType,
                submitLabel: submitLabel,
                maxLength: maxLength
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
    }
    .padding(20)
    .background(.brandSecondary)
}
