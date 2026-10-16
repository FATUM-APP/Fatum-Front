//
//  LabeledToggle.swift
//  Fatum
//

import SwiftUI

/// A bordered row with a bold title, a short description and a trailing switch.
/// Matches the card styling used across the profile screens.
struct LabeledToggle: View {
    let title: String
    let message: String
    @Binding var isOn: Bool

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        HStack(spacing: layout.internalSpacing) {
            VStack(alignment: .leading, spacing: layout.tiny) {
                Text(title)
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)

                Text(message)
                    .fatumStyle(.footer)
                    .foregroundStyle(.text.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.brandPrimary)
        }
        .padding(layout.internalPadding)
        .background(.brandSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        LabeledToggle(
            title: "Establecer como dirección principal",
            message: "Se usará por defecto al solicitar servicios",
            isOn: .constant(true)
        )

        LabeledToggle(
            title: "Notificaciones",
            message: "Recibe avisos sobre tus servicios",
            isOn: .constant(false)
        )
    }
    .padding(20)
    .background(.brandSecondary)
}
