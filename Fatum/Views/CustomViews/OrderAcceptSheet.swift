//
//  OrderAcceptSheet.swift
//  Fatum
//

import SwiftUI

/// Asks the provider how long the order will take before accepting it.
/// The field only takes digits, so the time can't be negative; "Aceptar"
/// stays disabled until there is one, then passes the minutes to `onAccept` and closes.
struct OrderAcceptSheet: View {
    /// The order's current estimate (from the service), prefilled in the field.
    var initialMinutes: Int? = nil
    let onAccept: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var minutesText: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var minutes: Int? {
        Int(minutesText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: layout.spacingMedium) {
                LabeledTextField(
                    label: "Tiempo estimado en minutos",
                    placeholder: "Ej. 60",
                    text: $minutesText,
                    icon: "clock",
                    maxLength: 5,
                    keyboardType: .numberPad,
                    submitLabel: .done,
                    allowedCharacters: { _, newValue in newValue.filter(\.isNumber) }
                )

                Button("Aceptar") {
                    guard let minutes else { return }
                    onAccept(minutes)
                    dismiss()
                }
                .buttonStyle(.fatumButton(variant: .third))
                .disabled(minutes == nil)
                // `FatumButton` doesn't dim when disabled.
                .opacity(minutes == nil ? 0.5 : 1)

                Spacer()
            }
            .screenPadding()
            .background(.brandSecondary)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Aceptar orden")
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.text)
                    }
                    .accessibilityLabel("Cerrar")
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if let initialMinutes {
                minutesText = String(initialMinutes)
            }
        }
    }
}

#Preview {
    OrderAcceptSheet(initialMinutes: 60, onAccept: { _ in })
}
