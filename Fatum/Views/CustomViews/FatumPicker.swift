//
//  FatumPicker.swift
//  Fatum
//

import SwiftUI

/// A menu picker drawn inside the same bordered box as `FatumTextField`, so
/// both line up in a form. Uses the same horizontal padding as the text field
/// and a smaller vertical padding because the menu control is taller than a
/// line of text.
///
/// Pass `style: .login` on the screens shown before sign-in.
struct FatumPicker<Option: Hashable>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Option
    var style: FatumFieldStyle = .standard
    var icon: String? = nil
    let label: (Option) -> String

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        HStack(spacing: layout.internalSpacing) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(style.iconColor)
            }

            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(style.textColor)

            Spacer()
        }
        .fatumStyle(.body)
        .foregroundStyle(style.textColor)
        .padding(.horizontal, layout.internalPadding)
        .padding(.vertical, layout.smallPadding)
        .frame(maxWidth: .infinity)
        .background(style.fillColor)
        .clipShape(RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(style.borderColor, lineWidth: 1)
        )
    }
}

#Preview {
    @Previewable @State var gender: Gender = .MALE
    @Previewable @State var documentType: DocumentType = .ID

    VStack(spacing: 20) {
        FatumTextField(placeholder: "Nombre completo", text: .constant(""), style: .login, prefixIcon: "person")

        FatumPicker(
            title: "Género",
            options: Array(Gender.allCases),
            selection: $gender,
            style: .login,
            icon: "person.2"
        ) { $0.displayName }

        FatumPicker(
            title: "Tipo de documento",
            options: Array(DocumentType.allCases),
            selection: $documentType
        ) { $0.displayName }
    }
    .padding(20)
    .background(AppGradient.mainBackground)
}
