//
//  OrderAcceptSheet.swift
//  Fatum
//

import SwiftUI

/// Asks the provider how long the order will take before accepting it.
/// The field only takes digits, so the time can't be negative; "Aceptar"
/// stays disabled until there is one within `maxMinutes`, then passes the
/// minutes to `onAccept` and closes.
struct OrderAcceptSheet: View {
    /// The backend rejects more than a day (`Order.estimatedTime`, `MAX_ESTIMATED_TIME`).
    static let maxMinutes = 1440

    /// The order's current estimate (from the service), prefilled in the field.
    var initialMinutes: Int? = nil
    let onAccept: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var minutesText: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// `nil` while the field is empty or above `maxMinutes`.
    private var minutes: Int? {
        Int(minutesText).flatMap { $0 <= Self.maxMinutes ? $0 : nil }
    }

    private var isOverLimit: Bool {
        (Int(minutesText) ?? 0) > Self.maxMinutes
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: layout.spacingMedium) {
                LabeledTextField(
                    label: "Tiempo estimado en minutos",
                    placeholder: "Ej. 60",
                    text: $minutesText,
                    icon: "clock",
                    maxLength: 4,
                    keyboardType: .numberPad,
                    submitLabel: .done,
                    allowedCharacters: { _, newValue in newValue.filter(\.isNumber) }
                )

                Text(isOverLimit
                     ? "El tiempo no puede superar \(Self.maxMinutes) minutos (24 h)"
                     : "Máximo \(Self.maxMinutes) minutos (24 h)")
                    .fatumStyle(.footer)
                    .foregroundStyle(.text)

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
