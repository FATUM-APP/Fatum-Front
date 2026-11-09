//
//  LabeledCheckbox.swift
//  Fatum
//

import SwiftUI

/// Checkbox counterpart of `LabeledToggle`: a bordered row with a leading
/// checkbox, a bold title and a short description. The whole row is tappable.
struct LabeledCheckbox: View {
    let title: String
    let message: String
    @Binding var isOn: Bool

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: layout.internalSpacing) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(isOn ? .brandPrimary : .text)

                VStack(alignment: .leading, spacing: layout.tiny) {
                    Text(title)
                        .fatumStyle(.body)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)

                    Text(message)
                        .fatumStyle(.footer)
                        .foregroundStyle(.text)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(layout.internalPadding)
            .background(.brandSecondary)
            .clipShape(RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                    .stroke(Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var isOn = true

    LabeledCheckbox(
        title: "Precio negociable",
        message: "Permite que los clientes propongan un valor diferente",
        isOn: $isOn
    )
    .padding(20)
    .background(.brandSecondary)
}
